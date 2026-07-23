import { Server, Socket } from 'socket.io';
import { AuthenticatedSocket } from './socket.types';
import { authenticateSocket, removeSocketSession } from './socket.auth';
import { initializeMatchmakingHandlers } from '../matchmaking/matchmaking.handler';
import { initializeRoomHandlers } from '../rooms/room.handler';
import { initializeGameHandlers } from '../gameplay/game.handler';
import { initializeVoiceHandlers } from '../voice/voice.handler';
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

              for (const [socketId, sock] of io.sockets.sockets) {
                const s = sock as any;
                if (s.userId === inviteData.targetUserId) {
                  io.to(socketId).emit('invite.received', {
                    fromUserId: socket.userId,
                    fromUsername: socket.username,
                    roomCode: inviteData.roomCode,
                    timestamp: Date.now(),
                  });
                  logger.info('Invite sent', {
                    from: socket.userId,
                    to: inviteData.targetUserId,
                    roomCode: inviteData.roomCode
                  });
                  break;
                }
              }

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

              for (const [sid, sock] of io.sockets.sockets) {
                const s = sock as any;
                if (s.userId === frData.targetUserId) {
                  io.to(sid).emit('friend.requestAccepted', {
                    userId: socket.userId,
                    username: socket.username
                  });
                  break;
                }
              }
            } catch (err) {
              logger.error('Friend accept notification error', { error: err });
            }
          });

          // ═══ DIRECT MESSAGE (1-on-1 CHAT) ═══
          socket.on('dm.send', async (dmData: { targetUserId: string, message: string }) => {
            try {
              if (!socket.userId || !dmData?.targetUserId || !dmData?.message) return;

              const messageText = dmData.message.trim();
              if (messageText.length === 0 || messageText.length > 500) return;

              for (const [sid, sock] of io.sockets.sockets) {
                const s = sock as any;
                if (s.userId === dmData.targetUserId) {
                  io.to(sid).emit('dm.received', {
                    fromUserId: socket.userId,
                    fromUsername: socket.username,
                    message: messageText,
                    timestamp: Date.now(),
                  });
                  break;
                }
              }

              // Also send back to sender for confirmation
              socket.emit('dm.sent', {
                targetUserId: dmData.targetUserId,
                message: messageText,
                timestamp: Date.now(),
              });

              logger.info('DM sent', { from: socket.userId, to: dmData.targetUserId });
            } catch (error) {
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

        restoreMatchState();

        // ═══ BROADCAST ONLINE STATUS TO FRIENDS ═══
        const broadcastOnlineStatus = async () => {
          try {
            const prisma = (await import('../config/database')).default;
            const friends = await prisma.friend.findMany({
              where: {
                OR: [
                  { userOne: socket.userId },
                  { userTwo: socket.userId }
                ]
              }
            });

            for (const friend of friends) {
              const friendId = friend.userOne === socket.userId ? friend.userTwo : friend.userOne;
              for (const [sid, sock] of io.sockets.sockets) {
                const s = sock as any;
                if (s.userId === friendId) {
                  io.to(sid).emit('friend.statusUpdated', {
                    userId: socket.userId,
                    status: 'ONLINE'
                  });
                  break;
                }
              }
            }
          } catch (err) {
            // Silently ignore
          }
        };

        broadcastOnlineStatus();

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

      // Broadcast offline status to friends
      if (socket.userId) {
        try {
          const prisma = (await import('../config/database')).default;
          const friends = await prisma.friend.findMany({
            where: {
              OR: [
                { userOne: socket.userId },
                { userTwo: socket.userId }
              ]
            }
          });

          for (const friend of friends) {
            const friendId = friend.userOne === socket.userId ? friend.userTwo : friend.userOne;
            for (const [sid, sock] of io.sockets.sockets) {
              const s = sock as any;
              if (s.userId === friendId) {
                io.to(sid).emit('friend.statusUpdated', {
                  userId: socket.userId,
                  status: 'OFFLINE'
                });
                break;
              }
            }
          }
        } catch (err) {
          // Silently ignore
        }
      }

      await removeSocketSession(socket);
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