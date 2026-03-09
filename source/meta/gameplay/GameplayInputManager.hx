package meta.gameplay;

import gameObjects.userInterface.notes.Note;
import meta.Controls;

/**
 * Gameplay input manager.
 * Handles per-lane key states, unique press/release detection, and delegates
 * to IGameplayInputHandler for note lookup and scoring.
 */
class GameplayInputManager
{
	static final LANE_COUNT:Int = 4;

	var handler:IGameplayInputHandler;
	var controls:Controls;
	var bindings:Array<InputBindingKeys> = [];

	public function new(handler:IGameplayInputHandler, controls:Controls)
	{
		this.handler = handler;
		this.controls = controls;

		for (i in 0...LANE_COUNT)
			bindings.push(new InputBindingKeys(i));
	}

	public function handleInput():Void
	{
		if (!handler.isGameplayActive())
			return;

		var hold = [controls.LEFT, controls.DOWN, controls.UP, controls.RIGHT];

		for (lane in 0...LANE_COUNT)
		{
			var binding = bindings[lane];
			var nowPressed = hold[lane];
			var uniquePress = !binding.pressed && nowPressed;
			var uniqueRelease = binding.pressed && !nowPressed;

			if (uniquePress)
			{
				binding.pressed = true;
				handler.resetHoldTimer();

				if (!handler.isStunned())
				{
					var hitObject = handler.getClosestTap(lane);
					if (hitObject != null)
					{
						handler.goodNoteHit(hitObject);
					}
					else if (!handler.ignoreMisses() && handler.hasAnyHittableNote())
					{
						handler.noteMiss(lane);
					}
				}
			}

			if (uniqueRelease)
				binding.pressed = false;

			if (nowPressed && !handler.isStunned())
				handler.handleHoldSustains(lane);
		}

		for (lane in 0...LANE_COUNT)
		{
			bindings[lane].pressed = hold[lane];
			handler.setReceptorState(lane, hold[lane]);
		}
	}

	public function isAnyKeyHeld():Bool
	{
		return controls.LEFT || controls.DOWN || controls.UP || controls.RIGHT;
	}
}