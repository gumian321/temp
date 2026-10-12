using System;
using System.Collections.Generic;

[Serializable]
internal class MinesList
{
	public float time;

	public List<MineController> mines;

	public MinesList(float t, List<MineController> list)
	{
		time = t;
		mines = new List<MineController>(list);
	}
}
