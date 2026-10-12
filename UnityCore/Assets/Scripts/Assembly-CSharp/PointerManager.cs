using System.Collections;
using UnityEngine;
using UnityEngine.InputSystem;

public class PointerManager : SceneSingleton<PointerManager>
{
	[SerializeField]
	private Camera cam;

	[SerializeField]
	private LayerMask allowedLayerMask;

	[Space]
	public bool isPointerOn;

	private bool IsMouse;

	[SerializeField]
	private Transform pointerTrans;

	[SerializeField]
	private SpriteRenderer pointerSprite;

	[SerializeField]
	private Vector3 movingDirection;

	[SerializeField]
	private float movingSpeed = 0.1f;

	[SerializeField]
	private float xRange = 10f;

	[SerializeField]
	private float yRange = 7f;

	private float minX;

	private float maxX;

	private float minY;

	private float maxY;

	private Vector3 lastSavedMousePos;

	private float HorDir;

	private float VerDir;

	private bool isMoveUpClicked;

	private bool isMoveDownClicked;

	private bool isMoveLeftClicked;

	private bool isMoveRightClicked;

	private void OnEnable()
	{
		DisablePointer();
	}

	public void StartPointer()
	{
		pointerTrans.position = SceneSingleton<PlayerMovement>.Instance.transform.position;
		minX = SceneSingleton<PlayerMovement>.Instance.transform.position.x - xRange;
		maxX = SceneSingleton<PlayerMovement>.Instance.transform.position.x + xRange;
		minY = SceneSingleton<PlayerMovement>.Instance.transform.position.y - yRange;
		maxY = SceneSingleton<PlayerMovement>.Instance.transform.position.y + yRange;
		pointerTrans.gameObject.SetActive(value: true);
		isPointerOn = true;
		StartCoroutine(UpdatePointerPos());
	}

	public void DisablePointer()
	{
		StopAllCoroutines();
		isPointerOn = false;
		pointerTrans.gameObject.SetActive(value: false);
	}

	public void SetPointerSprite(Sprite sprite)
	{
		pointerSprite.sprite = sprite;
	}

	private void Update()
	{
		if (isPointerOn && IsMouse)
		{
			Vector2 vector = Mouse.current.position.ReadValue();
			pointerTrans.transform.position = new Vector2(cam.ScreenToWorldPoint(vector).x, cam.ScreenToWorldPoint(vector).y);
		}
	}

	private IEnumerator UpdatePointerPos()
	{
		while (true)
		{
			if (!IsMouse)
			{
				pointerTrans.position += movingDirection * movingSpeed;
				Vector2 vector = pointerTrans.position;
				vector.x = Mathf.Clamp(vector.x, minX, maxX);
				vector.y = Mathf.Clamp(vector.y, minY, maxY);
				pointerTrans.position = vector;
			}
			yield return new WaitForSecondsRealtime(0.02f);
		}
	}

	public Vector3 GetPointerPos()
	{
		if (IsMouse)
		{
			return GetMousePos();
		}
		return pointerTrans.position;
	}

	public CoreController GetCoreControllerUnderPointer()
	{
		if (IsMouse)
		{
			return CoreControllerUnderMouse();
		}
		return CoreControllerUnderPointer();
	}

	private CoreController CoreControllerUnderPointer()
	{
		RaycastHit2D[] array = Physics2D.RaycastAll(new Vector2(pointerTrans.position.x, pointerTrans.position.y), Vector2.zero, 0f, allowedLayerMask);
		for (int i = 0; i < array.Length; i++)
		{
			RaycastHit2D raycastHit2D = array[i];
			if (raycastHit2D.collider != null && raycastHit2D.collider.gameObject.layer == 6 && !Singleton<DetectionDataStore>.Instance.IsShieldLayer(raycastHit2D.collider.gameObject))
			{
				return raycastHit2D.transform.GetComponent<CoreController>();
			}
		}
		return null;
	}

	public void CurserMoved()
	{
		if (!IsMouse)
		{
			IsMouse = true;
			isMoveUpClicked = false;
			isMoveDownClicked = false;
			isMoveLeftClicked = false;
			isMoveRightClicked = false;
			movingDirection = Vector3.zero;
		}
	}

	private Vector3 GetMousePos()
	{
		RaycastHit2D raycastHit2D = Physics2D.Raycast(new Vector2(cam.ScreenToWorldPoint(Mouse.current.position.ReadValue()).x, cam.ScreenToWorldPoint(Mouse.current.position.ReadValue()).y), Vector2.zero, 0f, allowedLayerMask);
		if (raycastHit2D.collider != null)
		{
			lastSavedMousePos = raycastHit2D.point;
			lastSavedMousePos.z = 0f;
		}
		return lastSavedMousePos;
	}

	private CoreController CoreControllerUnderMouse()
	{
		RaycastHit2D[] array = Physics2D.RaycastAll(new Vector2(cam.ScreenToWorldPoint(Mouse.current.position.ReadValue()).x, cam.ScreenToWorldPoint(Mouse.current.position.ReadValue()).y), Vector2.zero, 0f, allowedLayerMask);
		for (int i = 0; i < array.Length; i++)
		{
			RaycastHit2D raycastHit2D = array[i];
			if (raycastHit2D.collider != null && raycastHit2D.collider.gameObject.layer == 6 && !Singleton<DetectionDataStore>.Instance.IsShieldLayer(raycastHit2D.collider.gameObject))
			{
				return raycastHit2D.transform.GetComponent<CoreController>();
			}
		}
		return null;
	}

	public void MoveUpClicked(bool down)
	{
		if (isMoveUpClicked != down)
		{
			IsMouse = false;
			if (down)
			{
				VerDir++;
			}
			else
			{
				VerDir--;
			}
			VerDir = Mathf.Clamp(VerDir, -1f, 1f);
			movingDirection.y = VerDir;
			isMoveUpClicked = down;
		}
	}

	public void MoveDownClicked(bool down)
	{
		if (isMoveDownClicked != down)
		{
			IsMouse = false;
			if (down)
			{
				VerDir--;
			}
			else
			{
				VerDir++;
			}
			VerDir = Mathf.Clamp(VerDir, -1f, 1f);
			movingDirection.y = VerDir;
			isMoveDownClicked = down;
		}
	}

	public void MoveLeftClicked(bool down)
	{
		if (isMoveLeftClicked != down)
		{
			IsMouse = false;
			if (down)
			{
				HorDir--;
			}
			else
			{
				HorDir++;
			}
			HorDir = Mathf.Clamp(HorDir, -1f, 1f);
			movingDirection.x = HorDir;
			isMoveLeftClicked = down;
		}
	}

	public void MoveRightClicked(bool down)
	{
		if (isMoveRightClicked != down)
		{
			IsMouse = false;
			if (down)
			{
				HorDir++;
			}
			else
			{
				HorDir--;
			}
			HorDir = Mathf.Clamp(HorDir, -1f, 1f);
			movingDirection.x = HorDir;
			isMoveRightClicked = down;
		}
	}
}
