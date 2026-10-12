using System;
using System.Collections.Generic;
using UnityEngine;

[Serializable]
public class CurserData
{
	public CurserTypes curserType;

	public List<Texture2D> cursorTexturesList;

	public List<Sprite> cursorSpritesList;

	public Vector2 hotSpot = Vector2.zero;
}
