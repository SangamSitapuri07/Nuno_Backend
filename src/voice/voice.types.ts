export interface VoiceRoom {
  roomId: string;
  participants: VoiceParticipant[];
  createdAt: number;
}

export interface VoiceParticipant {
  userId: string;
  username: string;
  socketId: string;
  isMuted: boolean;
  isSpeaking: boolean;
  joinedAt: number;
}

export interface SDPOffer {
  targetUserId: string;
  sdp: string;
}

export interface SDPAnswer {
  targetUserId: string;
  sdp: string;
}

export interface ICECandidate {
  targetUserId: string;
  candidate: string;
  sdpMid: string | null;
  sdpMLineIndex: number | null;
}

export interface VoiceJoinInput {
  roomId: string;
}