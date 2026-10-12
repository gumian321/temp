using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class CurserManager : Singleton<CurserManager>
{
	public Action OnCurserMove;

	public Action OnCurserHide;

	[SerializeField]
	private List<CurserData> CurserDatasList;

	private CursorMode cursorMode;

	private Vector2 mousePosition;

	private float curserStopTime;

	private float maxCurserStopTime = 3f;

	public bool isCurserActive => Cursor.visible;

	private void OnEnable()
	{
		mousePosition = Vector2.zero;
		SetCurser(CurserTypes.Normal);
	}

	public void HideMouseCurser()
	{
		if (Cursor.visible)
		{
			Cursor.visible = false;
			mousePosition = Mouse.current.position.ReadValue();
			if (OnCurserHide != null)
			{
				OnCurserHide();
			}
		}
	}

	public void EnableMouseCurser()
	{
		mousePosition = Mouse.current.position.ReadValue();
		curserStopTime = 0f;
		if (!Cursor.visible)
		{
			Cursor.visible = true;
			if (OnCurserMove != null)
			{
				OnCurserMove();
			}
		}
	}

	public void MoveMouseCurser()
	{
		if (SceneSingleton<PointerManager>.Instance != null)
		{
			SceneSingleton<PointerManager>.Instance.CurserMoved();
		}
		if (SceneSingleton<PlayerTurretManager>.Instance != null)
		{
			SceneSingleton<PlayerTurretManager>.Instance.isMouse = true;
		}
		mousePosition = Mouse.current.position.ReadValue();
		curserStopTime = 0f;
	}

	private void Update()
	{
		if (!Cursor.visible)
		{
			if (mousePosition != Mouse.current.position.ReadValue())
			{
				EnableMouseCurser();
			}
			return;
		}
		if (mousePosition == Mouse.current.position.ReadValue())
		{
			curserStopTime += Time.deltaTime;
		}
		else
		{
			MoveMouseCurser();
		}
		if (curserStopTime >= maxCurserStopTime)
		{
			HideMouseCurser();
		}
	}

	public void SetCurser(CurserTypes curserType, int count = 0)
	{
		if (curserType == CurserTypes.None)
		{
			Cursor.visible = false;
			return;
		}
		Cursor.visible = true;
		if (count < 0)
		{
			count = 0;
		}
		foreach (CurserData curserDatas in CurserDatasList)
		{
			if (curserDatas.curserType == curserType)
			{
				Texture2D texture2D = curserDatas.cursorTexturesList[count];
				Vector2 hotspot = new Vector2((float)texture2D.width * curserDatas.hotSpot.x, (float)texture2D.height * curserDatas.hotSpot.y);
				Cursor.SetCursor(texture2D, hotspot, cursorMode);
				if (SceneSingleton<PointerManager>.Instance != null && curserDatas.cursorSpritesList != null && count < curserDatas.cursorSpritesList.Count)
				{
					SceneSingleton<PointerManager>.Instance.SetPointerSprite(curserDatas.cursorSpritesList[count]);
				}
			}
		}
	}
}
