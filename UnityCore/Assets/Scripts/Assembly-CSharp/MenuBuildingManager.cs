using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;

public class MenuBuildingManager : MonoBehaviour
{
	[SerializeField]
	private LabCanvas labCanvas;

	[SerializeField]
	private Camera cam;

	[SerializeField]
	private LayerMask allowedLayerMask;

	[SerializeField]
	private bool deleteMode;

	[Space]
	[SerializeField]
	private Transform coresHolder;

	[SerializeField]
	private float snappingDistance = 1f;

	[SerializeField]
	private CoreController holdedPiece;

	[SerializeField]
	private Core holdedCore;

	[Space]
	[Header("Building Pieces")]
	[SerializeField]
	private List<CorePlacement> savedCores;

	[SerializeField]
	private List<CorePlacement> currentCores;

	[SerializeField]
	private List<Transform> hologramTransforms;

	[SerializeField]
	private List<Vector3> possibleBuildingSpaces;

	private Vector3 debuggingPos = new Vector3(-100f, -100f, -100f);

	private List<Vector3> Surroundings = new List<Vector3>
	{
		Vector3.left,
		Vector3.right,
		Vector3.up,
		Vector3.down,
		new Vector3(1f, 1f, 0f),
		new Vector3(-1f, -1f, 0f),
		new Vector3(-1f, 1f, 0f),
		new Vector3(1f, -1f, 0f)
	};

	private Vector3 lastSavedMousePos;

	private void Update()
	{
		if (EventSystem.current.IsPointerOverGameObject())
		{
			return;
		}
		if (holdedPiece != null)
		{
			Vector3 mousePos = GetMousePos(GetRaycast2D());
			Vector3 closestPossibleBuildingSpaces = GetClosestPossibleBuildingSpaces(mousePos);
			if (object.Equals(closestPossibleBuildingSpaces, debuggingPos))
			{
				holdedPiece.transform.position = mousePos;
			}
			else
			{
				holdedPiece.transform.localPosition = closestPossibleBuildingSpaces;
			}
		}
		if (Input.GetMouseButtonDown(0))
		{
			if (deleteMode)
			{
				CoreController coreControllerUnderMouse = GetCoreControllerUnderMouse(GetRaycast2D());
				if (coreControllerUnderMouse != null)
				{
					coreControllerUnderMouse.DestroyCore();
				}
			}
			else if (holdedPiece != null && !object.Equals(GetClosestPossibleBuildingSpaces(GetMousePos(GetRaycast2D())), debuggingPos))
			{
				BuildPiece(holdedCore, holdedPiece.transform.position);
			}
		}
		if (Input.GetMouseButtonDown(1) && holdedCore != null)
		{
			DeselectCore();
		}
	}

	public void SpawnShipPiece(Core core)
	{
		DeselectCore();
		labCanvas.EndDeleteMode();
		UpdatePossibleBuildingSpaces();
		holdedPiece = MasterPool.CreateNew(PrefabTypes.Object_ShipPart, coresHolder).GetComponent<CoreController>();
		holdedPiece.PreviewCore(core);
		holdedPiece.SetCoreRangeSprite(flag: true);
		holdedCore = core;
	}

	private void BuildPiece(Core core, Vector3 corePos)
	{
		CorePlacement corePlacement = new CorePlacement();
		CoreController component = MasterPool.CreateNew(PrefabTypes.Object_ShipPart, coresHolder).GetComponent<CoreController>();
		component.PreviewCore(core);
		component.transform.position = corePos;
		Vector3 localPos = new Vector3((int)component.transform.localPosition.x, (int)component.transform.localPosition.y, 0f);
		corePlacement.coreObj = component.gameObject;
		corePlacement.localPos = localPos;
		corePlacement.coreController = component;
		corePlacement.core = core;
		currentCores.Add(corePlacement);
		UpdatePossibleBuildingSpaces();
		RefershCores();
	}

	public void PieceDestroyed(CoreController core)
	{
		CorePlacement corePlacement = GetCorePlacement(core);
		if (corePlacement != null)
		{
			currentCores.Remove(corePlacement);
			ShowPossibleBuildingSpaces();
			RefershCores();
		}
	}

	private void ShowPossibleBuildingSpaces()
	{
		UpdatePossibleBuildingSpaces();
		foreach (Transform hologramTransform in hologramTransforms)
		{
			if (possibleBuildingSpaces.Contains(hologramTransform.position))
			{
				hologramTransform.gameObject.SetActive(value: true);
			}
			else
			{
				hologramTransform.gameObject.SetActive(value: false);
			}
		}
	}

	private void HidePossibleBuildingspaces()
	{
		foreach (Transform hologramTransform in hologramTransforms)
		{
			hologramTransform.gameObject.SetActive(value: false);
		}
	}

	private void RefershCores()
	{
	}

	private void UpdatePossibleBuildingSpaces()
	{
		possibleBuildingSpaces.Clear();
		foreach (Transform hologramTransform in hologramTransforms)
		{
			possibleBuildingSpaces.Add(hologramTransform.position);
		}
		foreach (CorePlacement currentCore in currentCores)
		{
			if (possibleBuildingSpaces.Contains(currentCore.localPos))
			{
				possibleBuildingSpaces.Remove(currentCore.localPos);
			}
		}
	}

	private Vector3 GetClosestPossibleBuildingSpaces(Vector3 mousePos)
	{
		Vector3 result = debuggingPos;
		float num = 1000f;
		foreach (Vector3 possibleBuildingSpace in possibleBuildingSpaces)
		{
			float num2 = Vector3.Distance(possibleBuildingSpace, mousePos);
			if (num2 < snappingDistance && num2 < num)
			{
				result = possibleBuildingSpace;
				num = num2;
			}
		}
		return result;
	}

	public List<Vector3> GetSurroundingEmpty(CoreController core, List<Vector3> Surrounding)
	{
		Vector3 corePos = GetCorePos(core);
		if (corePos == debuggingPos)
		{
			return new List<Vector3>();
		}
		List<Vector3> list = new List<Vector3>();
		foreach (Vector3 surrounding in Surroundings)
		{
			Vector3 localPos = corePos + surrounding;
			if (GetCoreAt(localPos) == null)
			{
				list.Add(surrounding);
			}
		}
		return list;
	}

	private Vector3 GetCorePos(CoreController core)
	{
		foreach (CorePlacement currentCore in currentCores)
		{
			if (currentCore.coreController == core)
			{
				return currentCore.localPos;
			}
		}
		return debuggingPos;
	}

	private CoreController GetCoreAt(Vector3 localPos)
	{
		foreach (CorePlacement currentCore in currentCores)
		{
			if (localPos == currentCore.localPos)
			{
				return currentCore.coreController;
			}
		}
		return null;
	}

	private CorePlacement GetCorePlacement(CoreController core)
	{
		foreach (CorePlacement currentCore in currentCores)
		{
			if (object.Equals(currentCore.coreController, core))
			{
				return currentCore;
			}
		}
		return null;
	}

	private void DeselectCore()
	{
		if (!(holdedPiece == null))
		{
			Object.Destroy(holdedPiece.gameObject);
			holdedPiece = null;
			holdedCore = null;
		}
	}

	public void SetDeleteMode(bool x)
	{
		DeselectCore();
		deleteMode = x;
	}

	public void SaveCores()
	{
		savedCores = new List<CorePlacement>(currentCores);
		DeselectCore();
		HidePossibleBuildingspaces();
	}

	public void ResetCores()
	{
		DestroyAllCores();
		foreach (CorePlacement savedCore in savedCores)
		{
			BuildPiece(savedCore.core, savedCore.localPos);
		}
		savedCores.Clear();
		ShowPossibleBuildingSpaces();
	}

	public void DestroyAllCores()
	{
		int count = currentCores.Count;
		for (int i = 0; i < count; i++)
		{
			currentCores[0].coreController.DestroyCore();
		}
		ShowPossibleBuildingSpaces();
	}

	private RaycastHit2D GetRaycast2D()
	{
		return Physics2D.Raycast(new Vector2(cam.ScreenToWorldPoint(Input.mousePosition).x, cam.ScreenToWorldPoint(Input.mousePosition).y), Vector2.zero, 0f, allowedLayerMask);
	}

	private Vector3 GetMousePos(RaycastHit2D hit)
	{
		if (hit.collider != null)
		{
			lastSavedMousePos = hit.point;
			lastSavedMousePos.z = 0f;
		}
		return lastSavedMousePos;
	}

	private CoreController GetCoreControllerUnderMouse(RaycastHit2D hit)
	{
		if (hit.collider != null && hit.collider.gameObject.layer == 6)
		{
			return hit.transform.GetComponent<CoreController>();
		}
		return null;
	}
}
