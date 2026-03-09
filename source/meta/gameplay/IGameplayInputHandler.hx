package meta.gameplay;

import gameObjects.userInterface.notes.Note;

/**
 * Handler interface for gameplay input
 */
interface IGameplayInputHandler
{
	/** Returns the single closest hittable tap note in the lane, or null. */
	function getClosestTap(lane:Int):Note;

	/** Called when a note is hit successfully. */
	function goodNoteHit(note:Note):Void;

	/** Called when a lane is missed (wrong key or ghost tap). */
	function noteMiss(lane:Int):Void;

	/** Called each frame to hit sustain notes while key is held. */
	function handleHoldSustains(lane:Int):Void;

	/** Updates receptor/strum visual state for a lane. */
	function setReceptorState(lane:Int, pressed:Bool):Void;

	/** Whether the player is stunned (e.g. from a miss). */
	function isStunned():Bool;

	/** Whether music/gameplay is active. */
	function isGameplayActive():Bool;

	/** Whether to ignore misses (e.g. perfect mode). */
	function ignoreMisses():Bool;

	/** True if any hittable player note exists in any lane. */
	function hasAnyHittableNote():Bool;

	/** Reset the hold timer (called on key press). */
	function resetHoldTimer():Void;
}