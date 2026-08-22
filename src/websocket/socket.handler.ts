import { Server, Socket } from 'socket.io';
import { AuthenticatedSocket } from './socket.types';
import { authenticateSocket, removeSocketSession } from './socket.auth';
import { initializeMatchmakingHandlers } from '../matchmaking/matchmaking.handler';
import matchmakingService from '../matchmaking/matchmaking.service';
import { initializeRoomHandlers } from '../rooms/room.handler';
import { initializeGameHandlers } from '../gameplay/game.handler';
import { initializeVoiceHandlers } from '../voice/voice.handler';
import friendsService from '../friends/friends.service';
import roomService from '../rooms/room.service';
import redisClient from '../config/redis';
import { SOCKET_EVENTS } from '../utils/constants';
import logger from '../utils/logger';

export const initializeSocketHandlers = (io: Server): void => {

  io.on('connection', (rawSocket: Socket) => {
    const socket = rawSocket as AuthenticatedSocket;

    logger.info('Socket connected', { socketId: socket.id });

    socket.on(SOCKET_EVENTS.AUTHENTICATE, async (data: { token: string }) => {
      if (!data?.token) {
        socket.emit(SOCKET_EVENTS.ERROR, {
          code: 'AUTH_FAILED',
          message: 'Token is required.',
        });
        return;
      }

      const success = await authenticateSocket(socket, data.token);

      if (success) {
        socket.join(`user:${socket.userId}`);

        socket.emit(SOCKET_EVENTS.AUTHENTICATED, {
          success: true,
          playerId: socket.userId,
        });

        // Prevent duplicate handler registration
        if (!(socket as any)._handlersRegistered) {
          initializeMatchmakingHandlers(io, socket);
          initializeRoomHandlers(io, socket);
          initializeGameHandlers(io, socket);
          initializeVoiceHandlers(io, socket);

          // ═══ CHAT HANDLER ═══
          socket.on(SOCKET_EVENTS.CHAT_SEND, async (chatData: { message: string }) => {
            try {
              if (!socket.userId || !socket.roomId || !chatData?.message) return;

              const messageText = chatData.message.trim();
              if (messageText.length === 0 || messageText.length > 200) return;

              io.to(socket.roomId).emit(SOCKET_EVENTS.CHAT_RECEIVED, {
                userId: socket.userId,
                username: socket.username,
                message: messageText,
                timestamp: Date.now(),
              });
            } catch (error) {
              logger.error('Chat error', { error });
            }
          });

          // ═══ INVITE FRIEND ═══
          socket.on('invite.send', async (inviteData: { targetUserId: string, roomCode: string }) => {
            try {
              if (!socket.userId || !inviteData?.targetUserId || !inviteData?.roomCode) return;

              // The personal room reaches the target on any instance; the
              // previous local scan also delivered a duplicate copy.
              io.to(`user:${inviteData.targetUserId}`).emit('invite.received', {
                fromUserId: socket.userId,
                fromUsername: socket.username,
                roomCode: inviteData.roomCode,
                timestamp: Date.now(),
              });

              socket.emit('invite.sent', { success: true });
            } catch (error) {
              logger.error('Invite error', { error });
            }
          });

          // ═══ ACCEPT INVITE ═══
          socket.on('invite.accept', async (acceptData: { roomCode: string }) => {
            try {
              if (!socket.userId || !acceptData?.roomCode) return;

              const roomService = (await import('../rooms/room.service')).default;

              // Accepting an invite means leaving whatever lobby you are in.
              //
              // joinRoom refuses with PLAYER_ALREADY_IN_ROOM when the player
              // is somewhere else, so a player sitting in a group could accept
              // an invite, see it apparently succeed, and never actually move
              // - they had to find and press Leave first, which nobody does.
              // Switching rooms IS the intent of accepting, so the old one is
              // released here and the players left behind are told about it.
              const targetRoomId = await redisClient.get(
                `room:code:${acceptData.roomCode}`
              );

              if (!targetRoomId) {
                socket.emit('error', {
                  code: 'ROOM_NOT_FOUND',
                  message: 'That room no longer exists.',
                });
                return;
              }

              const currentRoomId = await roomService.resolveActiveRoom(
                socket.userId
              );

              if (currentRoomId && currentRoomId !== targetRoomId) {
                const previous = await roomService.leaveRoom(socket.userId);
                socket.leave(currentRoomId);

                // Only emit when the room survived; leaveRoom destroys it and
                // returns null once the last player has gone.
                if (previous) {
                  io.to(currentRoomId).emit('room.updated', { room: previous });
                  io.to(currentRoomId).emit('room.playerLeft', {
                    userId: socket.userId,
                    username: socket.username,
                  });
                }

                logger.info('Left previous room to accept an invite', {
                  userId: socket.userId,
                  from: currentRoomId,
                  to: targetRoomId,
                });
              }

              const room = await roomService.joinRoom(
                socket.userId,
                socket.username,
                socket.id,
                { roomCode: acceptData.roomCode }
              );

              socket.join(room.roomId);
              (socket as any).roomId = room.roomId;

              socket.emit('room.joined', { room });
              io.to(room.roomId).emit('room.updated', { room });

              await friendsService.broadcastUserStatus(io, socket.userId);

              logger.info('Invite accepted', { userId: socket.userId, roomCode: acceptData.roomCode });
            } catch (error: any) {
              socket.emit('error', {
                code: error.code || 'SERVER_ERROR',
                message: error.message || 'Failed to join room.',
              });
            }
          });

          // ═══ FRIEND REQUEST ACCEPTED NOTIFICATION ═══
          socket.on('friend.requestAccepted', async (frData: { targetUserId: string }) => {
            try {
              if (!socket.userId || !frData?.targetUserId) return;

              io.to(`user:${frData.targetUserId}`).emit('friend.requestAccepted', {
                userId: socket.userId,
                username: socket.username,
              });
            } catch (err) {
              logger.error('Friend accept notification error', { error: err });
            }
          });

          // ═══ DIRECT MESSAGE (1-on-1 CHAT) ═══
          socket.on('dm.send', async (dmData: { targetUserId: string, message: string }) => {
            try {
              if (!socket.userId || !dmData?.targetUserId || !dmData?.message) return;

              // Stored first, THEN relayed.
              //
              // This used to forward the text and forget it, so the whole
              // conversation lived in the two apps' memory - gone on restart,
              // and a message to an offline friend was dropped rather than
              // waiting for them. The row is now the record and the socket is
              // just the live delivery on top of it. The service also owns
              // the length and friends-only rules so they cannot drift.
              const messagesService = (await import('../friends/messages.service')).default;

              const saved = await messagesService.send(
                socket.userId,
                dmData.targetUserId,
                dmData.message
              );

              io.to(`user:${dmData.targetUserId}`).emit('dm.received', {
                id: saved.id,
                fromUserId: socket.userId,
                fromUsername: socket.username,
                message: saved.body,
                timestamp: saved.createdAt.getTime(),
              });

              // Echoed back so the sender's own bubble carries the stored id
              // and the server's timestamp rather than a local guess.
              socket.emit('dm.sent', {
                id: saved.id,
                targetUserId: dmData.targetUserId,
                message: saved.body,
                timestamp: saved.createdAt.getTime(),
              });

              logger.info('DM sent', { from: socket.userId, to: dmData.targetUserId });
            } catch (error: any) {
              // Reported rather than swallowed: a rejected message that
              // silently vanishes looks like the app is broken.
              socket.emit('dm.failed', {
                targetUserId: dmData?.targetUserId,
                code: error?.code || 'SERVER_ERROR',
                message: error?.message || 'Message could not be sent.',
              });
              logger.error('DM error', { error });
            }
          });

          (socket as any)._handlersRegistered = true;
        }

        // ═══ RESTORE MATCH/ROOM STATE ═══
        const restoreMatchState = async () => {
          try {
            const redis = (await import('../config/redis')).default;
            const matchId = await redis.get(`match:player:${socket.userId}`);
            const roomId = await redis.get(`player:room:${socket.userId}`);

            if (matchId) {
              const matchExists = await redis.get(`game:${matchId}`);
              if (matchExists) {
                (socket as any).matchId = matchId;
                logger.info('Restored matchId', { userId: socket.userId, matchId });
              } else {
                await redis.del(`match:player:${socket.userId}`);
              }
            }

            if (roomId) {
              const roomExists = await redis.get(`room:${roomId}`);
              if (roomExists) {
                (socket as any).roomId = roomId;
                socket.join(roomId);
                logger.info('Restored roomId', { userId: socket.userId, roomId });
              } else {
                await redis.del(`player:room:${socket.userId}`);
              }
            }
          } catch (err) {
            logger.error('Restore state error', { error: err });
          }
        };

        // Fire-and-forget, but never unhandled.
        //
        // Both of these are deliberately not awaited - authentication should
        // not block on them - but an un-caught rejection from a floating
        // promise is fatal: Node terminates the process on unhandledRejection
        // by default, so one store blip during one player's login would
        // disconnect every player on the server. Attaching a catch keeps the
        // failure local to the player it happened to.
        restoreMatchState().catch((error) => {
          logger.error('Restore state failed', { userId: socket.userId, error });
        });

        // ═══ BROADCAST USER STATUS TO FRIENDS ═══
        friendsService.broadcastUserStatus(io, socket.userId).catch((error) => {
          logger.error('Status broadcast failed', {
            userId: socket.userId,
            error,
          });
        });

        logger.info('Socket authentication successful', {
          userId: socket.userId,
          socketId: socket.id,
        });
      }
    });

    // ═══ DISCONNECT ═══
    socket.on('disconnect', async (reason) => {
      logger.info('Socket disconnected', {
        socketId: socket.id,
        userId: socket.userId,
        reason,
      });

      if (socket.userId) {
        const isOffline = await removeSocketSession(socket, io);

        if (isOffline) {
          // The player has no sockets left anywhere, so any lobby they were
          // sitting in must release them. Without this the `player:room:` key
          // outlives the connection and every later Create Room / Join Room
          // fails with ALREADY_IN_ROOM until the key's one-hour TTL expires.
          //
          // A match in progress is deliberately left alone: game.handler owns
          // that lifecycle and supports reconnecting into a running game.
          // Drop them from the matchmaking queue too.
          //
          // Nothing did this, so a player who closed the app while searching
          // stayed queued. The queue is only processed when somebody else
          // joins it, and the next arrival was then paired with a socket that
          // no longer exists: both were removed from the queue, a room and a
          // match were created, and the live player got a "match found" for a
          // game whose opponent could never appear. Reproduced in a test
          // before this fix.
          try {
            await matchmakingService.leaveQueue(socket.userId);
          } catch (error) {
            logger.error('Failed to leave the queue on disconnect', {
              userId: socket.userId,
              error,
            });
          }

          try {
            const inMatch = await redisClient.get(`match:player:${socket.userId}`);
            if (!inMatch) {
              const room = await roomService.leaveRoom(socket.userId);
              if (room) {
                io.to(room.roomId).emit(SOCKET_EVENTS.ROOM_UPDATED, { room });
              }
            }
          } catch (error) {
            logger.error('Failed to release room on disconnect', {
              userId: socket.userId,
              error,
            });
          }

          await friendsService.broadcastUserStatus(io, socket.userId, 'OFFLINE');
        }
      } else {
        await removeSocketSession(socket, io);
      }
    });

    // ═══ ERROR ═══
    socket.on('error', (error) => {
      logger.error('Socket error', {
        socketId: socket.id,
        userId: socket.userId,
        error,
      });
    });
  });

  logger.info('Socket handlers initialized');
};