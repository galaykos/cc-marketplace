# Enhanced Input — UE 5.x

Re-read against Epic's Enhanced Input page on 2026-10-26: `showdebug enhancedinput`. Carried
from the upstream source without a re-read: the `PawnClientRestart` and User Settings items.
Legacy axis and action mappings are deprecated; do not write new input against them.

## Add the mapping context where it survives networking and respawn

- A pawn's `BeginPlay` can run before its controller possesses it. On a remote client, or after
  a respawn, `GetController()` is then null and `AddMappingContext` never happens, so input
  works in single player and dies in multiplayer.
- Add the context in an override of `APawn::PawnClientRestart()`, which runs on the owning
  client after possession, or in the PlayerController.

```cpp
void AMyCharacter::PawnClientRestart()
{
    Super::PawnClientRestart();
    if (const APlayerController* PC = Cast<APlayerController>(GetController()))
        if (auto* Subsystem = ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(PC->GetLocalPlayer()))
            Subsystem->AddMappingContext(DefaultMappingContext, /*Priority*/ 0);
}
```

## Rebinding goes through User Settings, not the IMC asset

1. Project Settings → Engine → Enhanced Input → turn on **Enable User Settings**. Without it,
   player-mappable keys do nothing.
2. Give each remappable mapping (on the Input Action, or per mapping in the `IMC_`) **Player
   Mappable Key Settings** with a unique **Name**. That name is the save key.
3. Register the context with the settings object, either with
   `Subsystem->GetUserSettings()->RegisterInputMappingContext(IMC)`, or by passing
   `FModifyContextOptions` with `bNotifyUserSettings = true` to `AddMappingContext`.
4. Remap with `UEnhancedInputUserSettings::MapPlayerKey` (an `FMapPlayerKeyArgs` naming the
   mapping, slot and new key), reset with `UnmapPlayerKey`, and persist with `SaveSettings`.

The settings object belongs to the `UEnhancedInputLocalPlayerSubsystem`, one per local player,
so it exists only while that local player does.

## Debugging

`showdebug enhancedinput` in PIE shows the input actions and mappings the project is using.
