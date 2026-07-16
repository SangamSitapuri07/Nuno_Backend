import { z } from 'zod';

export const updateProfileSchema = z.object({
  username: z
    .string()
    .min(3, 'Username must be at least 3 characters')
    .max(20, 'Username must be at most 20 characters')
    .regex(
      /^[a-zA-Z0-9_]+$/,
      'Username can only contain letters, numbers, and underscores'
    )
    .optional(),
  avatarUrl: z
    .string()
    .url('Invalid avatar URL')
    .optional(),
});

export const updateSettingsSchema = z.object({
  language: z.string().min(2).max(10).optional(),
  musicVolume: z.number().min(0).max(100).optional(),
  soundVolume: z.number().min(0).max(100).optional(),
  voiceVolume: z.number().min(0).max(100).optional(),
  pushToTalk: z.boolean().optional(),
  notifications: z.boolean().optional(),
  darkMode: z.boolean().optional(),
});

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;
export type UpdateSettingsInput = z.infer<typeof updateSettingsSchema>;