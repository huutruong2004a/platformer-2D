# PROJECT CONTEXT: PICO PARK CLONE (FLUTTER) Dưới đây là kiến trúc và quy tắc bắt buộc cho dự án này. Mọi code sinh ra phải tuân thủ cấu trúc thư mục và tech stack này:

PROJECT CONTEXT: PICO PARK CLONE (FLUTTER)

Role: You are a Senior Flutter Game Developer specializing in the Flame Engine.
Project: "Pico Flutter" - A co-op multiplayer 2D platformer inspired by "Pico Park".
Goal: Build a production-ready game in 8 weeks, featuring Realtime Multiplayer and AI Assistance.

1. TECH STACK (NON-NEGOTIABLE)

Framework: Flutter (Latest stable).

Game Engine: flame + flame_forge2d (Box2D physics).

Map System: flame_tiled (Parsing .tmj files from Tiled Map Editor).

Backend/Multiplayer: supabase_flutter (Using Realtime Broadcast for low-latency position sync).

State Management: provider (For UI & Lobby state).

Routing: go_router (Supports deep-linking to rooms).

AI Integration: google_generative_ai (Gemini API) for in-game RAG Chatbot.

Assets: Kenney 1-Bit Platformer Pack (Pixel Art).

2. DIRECTORY STRUCTURE (FEATURE-FIRST)

Based on Google's "Super Dash" architecture but simplified for Provider.

lib/
├── app/ # App configuration
│ ├── router/ # GoRouter config
│ └── view/ # MaterialApp wrapper
├── core/ # Shared utilities
│ ├── constants/ # GameSpeed, Gravity, AssetPaths
│ └── utils/ # Helper functions
├── data/ # Data Layer
│ └── supabase_service.dart # Supabase Client & Realtime Logic
├── game/ # --- FLAME GAME CORE ---
│ ├── components/ # Game Entities
│ │ ├── player/ # PlayerBody (Physics) & PlayerSprite
│ │ ├── level/ # Ground, Walls (Static bodies)
│ │ └── objects/ # Rope, Box, Door, Traps, Buttons
│ ├── inputs/ # Keyboard & Touch handlers
│ ├── pico_game.dart # Main class extends Forge2DGame
│ └── pico_world.dart # World logic
├── features/ # --- NON-GAME FEATURES ---
│ ├── ai_chat/ # Gemini Chatbot Logic (RAG)
│ └── leaderboard/ # Supabase Scoreboard
├── providers/ # --- STATE MANAGEMENT ---
│ ├── game_state.dart # Score, Current Level
│ └── room_provider.dart # Multiplayer Logic (Join/Host/Sync)
├── screens/ # --- FLUTTER UI ---
│ ├── menu/ # Main Menu
│ ├── lobby/ # Room ID Input & Player List
│ ├── game/ # GameWidget Overlay
│ └── settings/ # Audio/Theme settings
└── main.dart # Entry point

3. CORE GAMEPLAY MECHANICS

A. Physics (Forge2D)

Gravity: Vector2(0, 50) (Strong downward force for snappy platforming).

Player:

Shape: CircleShape (Radius: ~0.4m) to avoid getting stuck on corners.

BodyType: dynamic.

Fixture: Friction (0.5), Restitution (0.0 - No bounce on ground).

Movement: body.linearVelocity (X-axis), applyLinearImpulse (Jump).

Ground: Parsed from Tiled ObjectGroup named "Collisions". BodyType.static.

B. The Rope (Co-op Mechanic)

Component: DistanceJoint connecting two Player Bodies.

Properties:

frequencyHz: 3.0 (Elastic/Bouncy feel).

dampingRatio: 0.5.

Visuals: Draw a QuadraticBezier curve between players. Rope color matches player colors.

C. Map Design (Tiled)

Tile Size: 16x16px.

Layers:

Ground (Tile Layer): Visible blocks.

Decorations (Tile Layer): Background.

Collisions (Object Layer): Rectangles for Physics Bodies.

SpawnPoints (Object Layer): Points for P1-P4 start positions.

Triggers (Object Layer): Areas that trigger traps or level completion.

4. MULTIPLAYER ARCHITECTURE (SUPABASE)

Protocol: WebSockets (Supabase Realtime Broadcast). NO Database writes for movement.

Logic Flow:

Join Room: Enter Room ID -> Subscribe to Channel room\_{id}.

Sync Strategy:

Authority: Each client simulates their own physics locally.

Broadcast: Send {id, x, y, velocity_x, velocity_y, anim_state} every 50ms (Throttle).

Interpolation: Remote clients smoothly lerp "Ghost Players" to received coordinates.

Events:

player_join: Sync skin color/name.

move: Position sync.

action: Rope connect/disconnect.

level_end: All players at door.

5. AI & INTELLIGENT FEATURES (GRADING CRITERIA)

A. RAG Chatbot (Gemini API)

Goal: Assist players stuck on levels without giving direct spoilers.

Data Source: assets/data/level_guides.txt (Contains hints for each level).

System Prompt: "You are PicoBot. Use the provided level context to give subtle hints. Do not solve the puzzle directly. Keep answers under 20 words."

UI: Overlay Chat Widget in Pause Menu.

B. Smart Bots (Optional Fallback)

If a player disconnects, a simple State Machine AI takes over:

State: Follow Leader (nearest player).

Action: Jump if Leader jumps.

6. LEVEL CONTENT ROADMAP

Levels 1-5 (The Basics): Jump, Move, Key & Door mechanics.

Levels 6-10 (The Rope): Players tied together. Must jump in sync.

Levels 11-15 (The Push): Heavy boxes requiring multiple players to push (Forge2D mass calculation).

Levels 16-20 (The Gimmicks): Hidden traps, disappearing floors, wind zones.

7. CODING GUIDELINES

Font: Sử dụng GoogleFonts.vt323() cho toàn bộ UI/UX để đảm bảo phong cách Pixel Art đồng bộ.

Optimization: Profile for < 16ms/frame. Use SpriteBatch for particles.

Clean Code: Separate Physics logic (BodyComponent) from Visual logic (SpriteComponent).

Environment: Use .env file for Supabase Keys.

Debug Protocol: If a bug is severe or persistent, SEARCH STACKOVERFLOW or Github Issues immediately to find a solution.

8. IMMEDIATE NEXT TASK

Goal: [INSERT TASK HERE - e.g., "Create the Physics Player Component and load it from Tiled"]

9. BACKLOG / FUTURE TASKS

- [ ] Dynamic Camera: Implement a camera that zooms in/out to keep all players in view (Pico Park style). Currently using fixed full-map view for development.
- [ ] Realtime Co-op: Implement Supabase syncing.

10. GAME CONFIGURATION (REFERENCE)

```dart
import 'package:flame/components.dart';

class GameConfig {
  // Physics - Cấu hình "Nặng & Dứt khoát"
  static final Vector2 gravity = Vector2(0, 2500.0);
  static const double jumpForce = -60.0; // Vận tốc nhảy trực tiếp
  static const double doubleJumpForce = -60.0;
  static const double moveSpeed = 50.0; // Chạy chậm lại để dễ kiểm soát
  static const double longJumpMultiplier = 0.55; // Nhảy xa vừa phải
  static const double terminalVelocity = 3000.0;

  // Player
  static const double playerRadius = 8.0;
  static const double playerFriction = 10.0; // Ma sát cực cao để dừng ngay lập tức

  // Multiplayer
  static const int syncIntervalMs = 50;

  // Assets
  static const double tileSize = 18.0;
}
```

11.name class tiled in game
tên class block là Ground, class đồng xu là Coin, class bẫy là Trap 3 layer 1 cái là hình, 1 cái là block tên Ground, 1 cái là điểm spawn, cái hố ẩn class là Hole, Ladder là cầu thang trong map

#Luôn luôn trả lời và giải thích cho tôi bằng tiếng việt.
