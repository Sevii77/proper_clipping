# Proper Clipping

---

Proper Clipping is a visual and physical clipping tool for Garry's Mod with the ability to load in clips from older clipping tools [A](https://steamcommunity.com/sharedfiles/filedetails/?id=106753151) and [B](https://steamcommunity.com/sharedfiles/filedetails/?id=238138995) while also allowing them to load in clips from Proper Clipping.

Has [StarfallEx](https://github.com/thegrb93/StarfallEx) and [Expression2](https://github.com/wiremod/wire) functions

StarfallEx:
- ENTITY.addClip
- ENTITY.removeClips
- ENTITY.removeClip
- ENTITY.removeClipByIndex
- ENTITY.clipExists
- ENTITY.getClipIndex
- ENTITY.physicsClipsLeft
- ENTITY.getClipData

Expression2:
- ENTITY.addClip
- ENTITY.removeClips
- ENTITY.removeClip
- ENTITY.removeClipByIndex
- ENTITY.getClipIndex
- ENTITY.physicsClipsLeft
- ENTITY.getClipData

---

Server Convars:
- proper_clipping_max_physics
- proper_clipping_max_visual_server

Client Convars:
- proper_clipping_max_visual
- proper_clipping_mode
- proper_clipping_offset
- proper_clipping_physics
- proper_clipping_pitch
- proper_clipping_yaw
- proper_clipping_undo

---

Hooks:
- [Shared] ProperClippingCanPhysicsClip(Entity ent, Player ply or nil) -> return false to disallow physics clips
- [Shared] ProperClippingPhysicsClipped(Entity ent, table normals, table distances)
- [Shared] ProperClippingPhysicsReset(Entity ent)
- [Shared] ProperClippingClipAdded(Entity ent, Vector normal, number distance, boolean inside, boolean physics)
- [Shared] ProperClippingClipsRemoved(Entity ent)
- [Server] ProperClippingClipRemoved(Entity ent, number index)
- [Server] ProperClippingClipsNetworked(Entity ent, Player ply or nil)

- [Shared] CanTool(Player ply, TraceResult trace, "proper_clipping_physics") -> return false to disallow physics clips

---

[Available on the Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2256491552)
