package meta.gameplay;

/**
 * Per-lane input binding.
 * Maps one key to one lane and tracks press state.
 */
class InputBindingKeys
{
	/** Whether this lane's key is currently pressed. */
	public var pressed:Bool = false;

	/** Lane index (0-3: left, down, up, right). */
	public var lane:Int;

	public function new(lane:Int)
	{
		this.lane = lane;
	}
}