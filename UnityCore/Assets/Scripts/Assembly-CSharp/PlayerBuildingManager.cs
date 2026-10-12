using System.Collections.Generic;
using UnityEngine;

public class PlayerBuildingManager : SceneSingleton<PlayerBuildingManager>, IBuilder
{
	[SerializeField]
	private Transform Holder;

	[SerializeField]
	private GameObject shipHolegramsParent;

	[SerializeField]
	private CoreController holdedPiece;

	[SerializeField]
	private CoreController highlightedPieceUndermouse;

	[SerializeField]
	private int switchsNum;

	[SerializeField]
	private int duplicateNum;

	[SerializeField]
	private int moveCoreNum;

	[SerializeField]
	private int reinforceWall;

	private CorePlacement firstCorePlacement;

	private CorePlacement secondCorePlacement;

	[SerializeField]
	private float snappingDistance;

	private int buildingLimitX;

	private int buildingLimitY;

	[Space]
	[Header("Building Pieces")]
	[SerializeField]
	private GameObject emptyFirstCoreBackground;

	[SerializeField]
	private GameObject emptySecondCoreBackground;

	[SerializeField]
	private GameObject emptyThirdCoreBackground;

	[SerializeField]
	private List<CorePlacement> currentCores;

	[SerializeField]
	private List<GameObject> buildingHologramsObjs;

	[SerializeField]
	private List<Vector3> possibleBuildingSpaces;

	private Queue<Core> coresBuildingQueue;

	private List<Vector3> Directions = new List<Vector3>
	{
		Vector3.left,
		Vector3.right,
		Vector3.up,
		Vector3.down
	};

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

	private Vector3 debuggingPos = new Vector3(-100f, -100f, -100f);

	private List<CorePlacement> visitedCores;

	private List<CorePlacement> unVisitedCores;

	[SerializeField]
	private List<CorePlacement> MainCores;

	private List<Vector3> mainCoreNeighborsPos = new List<Vector3>
	{
		new Vector3(-1f, 0f, 0f),
		new Vector3(-1f, 1f, 0f),
		new Vector3(0f, 2f, 0f),
		new Vector3(1f, 2f, 0f),
		new Vector3(2f, 1f, 0f),
		new Vector3(2f, 0f, 0f),
		new Vector3(0f, -1f, 0f),
		new Vector3(1f, -1f, 0f)
	};

	private void Start()
	{
		Singleton<PlayerDecorationManager>.Instance.UpdateShipDecorations(GetCoresPositions(includeMainCore: true));
		coresBuildingQueue = new Queue<Core>();
	}

	private void Update()
	{
		if (holdedPiece != null)
		{
			Vector3 pointerPos = SceneSingleton<PointerManager>.Instance.GetPointerPos();
			Vector3 closestPossibleBuildingSpaces = GetClosestPossibleBuildingSpaces(pointerPos);
			if (object.Equals(closestPossibleBuildingSpaces, debuggingPos))
			{
				holdedPiece.transform.position = pointerPos;
			}
			else
			{
				holdedPiece.transform.localPosition = closestPossibleBuildingSpaces;
			}
		}
		HighlightUnderMouse();
		if (firstCorePlacement == null)
		{
			return;
		}
		Vector3 pointerPos2 = SceneSingleton<PointerManager>.Instance.GetPointerPos();
		Vector3 closestCorePos = GetClosestCorePos(pointerPos2);
		if (object.Equals(closestCorePos, debuggingPos))
		{
			firstCorePlacement.coreObj.transform.position = pointerPos2;
			if (secondCorePlacement != null)
			{
				TweenController.KillTweens(secondCorePlacement.coreObj.transform);
				TweenController.LocalMove(secondCorePlacement.coreObj.transform, secondCorePlacement.localPos, TweenDuration.Super_Short, ignoreTimeScale: true);
				secondCorePlacement.coreController.DisableHighLightCore();
				emptySecondCoreBackground.SetActive(value: true);
				emptySecondCoreBackground.transform.localPosition = secondCorePlacement.localPos;
				secondCorePlacement = null;
			}
			return;
		}
		firstCorePlacement.coreObj.transform.localPosition = closestCorePos;
		CorePlacement corePlacement = GetCorePlacement(closestCorePos);
		if (secondCorePlacement != null && !object.Equals(corePlacement, secondCorePlacement))
		{
			TweenController.KillTweens(secondCorePlacement.coreObj.transform);
			TweenController.LocalMove(secondCorePlacement.coreObj.transform, secondCorePlacement.localPos, TweenDuration.Super_Short, ignoreTimeScale: true);
			secondCorePlacement.coreController.DisableHighLightCore();
			emptySecondCoreBackground.SetActive(value: true);
			emptySecondCoreBackground.transform.localPosition = secondCorePlacement.localPos;
			secondCorePlacement = null;
		}
		if (!object.Equals(corePlacement, secondCorePlacement))
		{
			secondCorePlacement = corePlacement;
			TweenController.KillTweens(secondCorePlacement.coreObj.transform);
			TweenController.LocalMove(secondCorePlacement.coreObj.transform, firstCorePlacement.localPos, TweenDuration.Super_Short, ignoreTimeScale: true);
			secondCorePlacement.coreController.HighLightCore();
			secondCorePlacement.coreController.SetCoreRangeSprite(flag: true);
			emptyThirdCoreBackground.SetActive(value: true);
			emptyThirdCoreBackground.transform.localPosition = secondCorePlacement.localPos;
		}
	}

	private void HighlightUnderMouse()
	{
		if (!SceneSingleton<GameManager>.Instance.IsBuildingMode() || (duplicateNum == 0 && switchsNum == 0 && reinforceWall == 0 && moveCoreNum == 0))
		{
			return;
		}
		if (firstCorePlacement == null && holdedPiece == null)
		{
			CoreController coreControllerUnderPointer = SceneSingleton<PointerManager>.Instance.GetCoreControllerUnderPointer();
			if (coreControllerUnderPointer == null || coreControllerUnderPointer == currentCores[0].coreController)
			{
				if (highlightedPieceUndermouse != null)
				{
					highlightedPieceUndermouse.DeselectCore();
				}
				return;
			}
			if (highlightedPieceUndermouse != null && coreControllerUnderPointer != highlightedPieceUndermouse)
			{
				highlightedPieceUndermouse.DeselectCore();
			}
			if ((reinforceWall == 0 || coreControllerUnderPointer.CanAddWall()) && (moveCoreNum == 0 || !MoveWillDisconnectCores(coreControllerUnderPointer)))
			{
				highlightedPieceUndermouse = coreControllerUnderPointer;
				highlightedPieceUndermouse.SelectCore();
			}
		}
		else if (highlightedPieceUndermouse != null)
		{
			highlightedPieceUndermouse.DeselectCore();
			highlightedPieceUndermouse = null;
		}
	}

	public void LeftMouseClick()
	{
		if (IsHoldingCore())
		{
			Vector3 pointerPos = SceneSingleton<PointerManager>.Instance.GetPointerPos();
			Vector3 closestPossibleBuildingSpaces = GetClosestPossibleBuildingSpaces(pointerPos);
			if (object.Equals(closestPossibleBuildingSpaces, debuggingPos))
			{
				holdedPiece.transform.position = pointerPos;
			}
			else
			{
				holdedPiece.transform.localPosition = closestPossibleBuildingSpaces;
			}
			if (!object.Equals(closestPossibleBuildingSpaces, debuggingPos))
			{
				if (moveCoreNum != 0)
				{
					moveCoreNum--;
					emptyFirstCoreBackground.SetActive(value: false);
					DestroyUnconnectedCores();
				}
				BuildPiece();
			}
		}
		else if (duplicateNum != 0)
		{
			CoreController coreControllerUnderPointer = SceneSingleton<PointerManager>.Instance.GetCoreControllerUnderPointer();
			if (!(coreControllerUnderPointer == currentCores[0].coreController))
			{
				if (coreControllerUnderPointer != null)
				{
					SpawnShipPiece(coreControllerUnderPointer.GetCurrentCore());
					duplicateNum--;
				}
				Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Hand, duplicateNum);
			}
		}
		else if (switchsNum != 0)
		{
			if (firstCorePlacement == null)
			{
				CoreController coreControllerUnderPointer2 = SceneSingleton<PointerManager>.Instance.GetCoreControllerUnderPointer();
				if (!(coreControllerUnderPointer2 == currentCores[0].coreController) && !(coreControllerUnderPointer2 == null))
				{
					firstCorePlacement = GetCorePlacement(coreControllerUnderPointer2);
					firstCorePlacement.coreController.HighLightCore();
					currentCores.Remove(firstCorePlacement);
					emptyFirstCoreBackground.SetActive(value: true);
					emptyFirstCoreBackground.transform.localPosition = firstCorePlacement.localPos;
					HighLightCores(coreControllerUnderPointer2);
					Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.Core_Change);
				}
				return;
			}
			Vector3 closestCorePos = GetClosestCorePos(SceneSingleton<PointerManager>.Instance.GetPointerPos());
			if (secondCorePlacement != null && !object.Equals(closestCorePos, debuggingPos))
			{
				secondCorePlacement.localPos = firstCorePlacement.localPos;
				secondCorePlacement.coreObj.transform.localPosition = firstCorePlacement.localPos;
				secondCorePlacement = null;
				firstCorePlacement.localPos = closestCorePos;
				firstCorePlacement.coreObj.transform.localPosition = closestCorePos;
				currentCores.Add(firstCorePlacement);
				firstCorePlacement = null;
				switchsNum--;
				emptyFirstCoreBackground.SetActive(value: false);
				emptySecondCoreBackground.SetActive(value: false);
				emptyThirdCoreBackground.SetActive(value: false);
				DisableHighLightCores();
				RefershCores();
				Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.Core_Change);
				Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Hand, switchsNum);
			}
		}
		else if (reinforceWall != 0)
		{
			CoreController coreControllerUnderPointer3 = SceneSingleton<PointerManager>.Instance.GetCoreControllerUnderPointer();
			if (!(coreControllerUnderPointer3 == null) && !(coreControllerUnderPointer3 == currentCores[0].coreController) && coreControllerUnderPointer3.CanAddWall())
			{
				coreControllerUnderPointer3.AddWall();
				reinforceWall--;
				if (highlightedPieceUndermouse != null)
				{
					highlightedPieceUndermouse.DeselectCore();
					highlightedPieceUndermouse = null;
				}
			}
		}
		else if (moveCoreNum != 0)
		{
			CoreController coreControllerUnderPointer4 = SceneSingleton<PointerManager>.Instance.GetCoreControllerUnderPointer();
			if (!(coreControllerUnderPointer4 == null) && !(coreControllerUnderPointer4 == currentCores[0].coreController) && !MoveWillDisconnectCores(coreControllerUnderPointer4))
			{
				holdedPiece = coreControllerUnderPointer4;
				CorePlacement corePlacement = GetCorePlacement(holdedPiece);
				currentCores.Remove(corePlacement);
				SceneSingleton<PlayerCoresManager>.Instance.RemoveCoreController(coreControllerUnderPointer4);
				emptyFirstCoreBackground.SetActive(value: true);
				emptyFirstCoreBackground.transform.localPosition = corePlacement.localPos;
				ShowPossibleBuildingSpaces();
			}
		}
	}

	public void SpawnShipCenterPiece(Core core)
	{
		CoreController component = MasterPool.CreateNew(PrefabTypes.Object_ShipPart, Holder.transform).GetComponent<CoreController>();
		component.PreviewCore(core);
		component.transform.localPosition = new Vector3(0.5f, 0.5f, 0f);
		List<Vector3> obj = new List<Vector3>
		{
			new Vector3(0f, 0f, 0f),
			new Vector3(1f, 0f, 0f),
			new Vector3(0f, 1f, 0f),
			new Vector3(1f, 1f, 0f)
		};
		MainCores = new List<CorePlacement>();
		foreach (Vector3 item in obj)
		{
			CorePlacement corePlacement = new CorePlacement();
			corePlacement.coreObj = component.gameObject;
			corePlacement.localPos = item;
			corePlacement.coreController = component;
			currentCores.Add(corePlacement);
			MainCores.Add(corePlacement);
		}
		component.BuildCore(this);
		UpdateShipSize();
		UpdatePossibleBuildingSpaces();
		Singleton<PlayerDecorationManager>.Instance.UpdateShipDecorations(GetCoresPositions(includeMainCore: true));
	}

	public void SpawnShipPiece(Core core)
	{
		if (IsHoldingCore())
		{
			coresBuildingQueue.Enqueue(core);
			return;
		}
		ShowPossibleBuildingSpaces();
		holdedPiece = MasterPool.CreateNew(PrefabTypes.Object_ShipPart, Holder.transform).GetComponent<CoreController>();
		holdedPiece.PreviewCore(core);
		holdedPiece.SetCoreRangeSprite(flag: true);
		HighLightCores(holdedPiece);
		holdedPiece.SetCoreSortingLayer(flag: true);
	}

	public void PieceDestroyed(CoreController core)
	{
		CorePlacement corePlacement = GetCorePlacement(core);
		if (corePlacement != null)
		{
			currentCores.Remove(corePlacement);
			SceneSingleton<PlayerCoresManager>.Instance.RemoveCoreController(corePlacement.coreController);
			DestroyUnconnectedCores();
			UpdateShipSize();
			UpdatePossibleBuildingSpaces();
			RefershCores();
			Singleton<PlayerDecorationManager>.Instance.UpdateShipDecorations(GetCoresPositions(includeMainCore: true));
		}
	}

	private void BuildPiece()
	{
		CorePlacement corePlacement = new CorePlacement();
		Vector3 localPos = new Vector3((int)holdedPiece.transform.localPosition.x, (int)holdedPiece.transform.localPosition.y, 0f);
		corePlacement.coreObj = holdedPiece.gameObject;
		corePlacement.localPos = localPos;
		corePlacement.coreController = holdedPiece;
		currentCores.Add(corePlacement);
		Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.Core_Change);
		holdedPiece.BuildCore(this);
		holdedPiece.SetCoreRangeSprite(flag: false);
		holdedPiece = null;
		SceneSingleton<PlayerCoresManager>.Instance.AddCoreController(corePlacement.coreController);
		HidePossibleBuildingspaces();
		UpdateShipSize();
		UpdatePossibleBuildingSpaces();
		RefershCores();
		DisableHighLightCores();
		Singleton<PlayerDecorationManager>.Instance.UpdateShipDecorations(GetCoresPositions(includeMainCore: true));
		if (coresBuildingQueue.Count > 0)
		{
			Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Hand, coresBuildingQueue.Count);
			SpawnShipPiece(coresBuildingQueue.Dequeue());
		}
		else if (switchsNum > 0)
		{
			Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Hand, switchsNum);
		}
		else if (duplicateNum > 0)
		{
			Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Hand, duplicateNum);
		}
		else if (moveCoreNum > 0)
		{
			Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Hand, moveCoreNum);
		}
		else
		{
			Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Normal);
		}
	}

	private void UpdateShipSize()
	{
		int num = 1;
		foreach (CorePlacement currentCore in currentCores)
		{
			if (Mathf.Abs(currentCore.localPos.x) > (float)num)
			{
				num = (int)Mathf.Abs(currentCore.localPos.x);
			}
			if (Mathf.Abs(currentCore.localPos.y) > (float)num)
			{
				num = (int)Mathf.Abs(currentCore.localPos.y);
			}
		}
		SceneSingleton<PlayerManager>.Instance.SetShipSize(num);
	}

	public void RefershCores()
	{
		SceneSingleton<PlayerCoresManager>.Instance.RefreshCores();
	}

	private void ShowPossibleBuildingSpaces()
	{
		UpdatePossibleBuildingSpaces();
		foreach (Vector3 possibleBuildingSpace in possibleBuildingSpaces)
		{
			GameObject gameObject = MasterPool.Get(PrefabTypes.Object_BuildingHologram, shipHolegramsParent.transform);
			gameObject.transform.localPosition = possibleBuildingSpace;
			TweenController.Scale(gameObject.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
			buildingHologramsObjs.Add(gameObject);
		}
	}

	private void HidePossibleBuildingspaces()
	{
		foreach (GameObject buildingHologramsObj in buildingHologramsObjs)
		{
			MasterPool.ReturnToPoolTransform(buildingHologramsObj, PrefabTypes.Object_BuildingHologram);
		}
		buildingHologramsObjs.Clear();
	}

	private void UpdatePossibleBuildingSpaces()
	{
		List<Vector3> list = new List<Vector3>();
		foreach (CorePlacement currentCore in currentCores)
		{
			foreach (Vector3 direction in Directions)
			{
				Vector3 vector = currentCore.localPos + direction;
				if (!IsLocalSpaceOccupied(vector) && !list.Contains(vector) && IsWithinLimits(vector))
				{
					list.Add(vector);
				}
			}
		}
		possibleBuildingSpaces = new List<Vector3>(list);
	}

	private bool IsWithinLimits(Vector3 localPos)
	{
		if ((float)(buildingLimitX + 1) < localPos.x)
		{
			return false;
		}
		if ((float)(-buildingLimitX) > localPos.x)
		{
			return false;
		}
		if ((float)(buildingLimitY + 1) < localPos.y)
		{
			return false;
		}
		if ((float)(-buildingLimitY) > localPos.y)
		{
			return false;
		}
		return true;
	}

	private bool IsLocalSpaceOccupied(Vector3 localPos)
	{
		foreach (CorePlacement currentCore in currentCores)
		{
			if (object.Equals(localPos, currentCore.localPos))
			{
				return true;
			}
		}
		return false;
	}

	private Vector3 GetClosestPossibleBuildingSpaces(Vector3 mousePos)
	{
		Vector3 result = debuggingPos;
		float num = 1000f;
		foreach (Vector3 possibleBuildingSpace in possibleBuildingSpaces)
		{
			float num2 = Vector3.Distance(Holder.TransformPoint(possibleBuildingSpace), mousePos);
			if (num2 < snappingDistance && num2 < num)
			{
				result = possibleBuildingSpace;
				num = num2;
			}
		}
		return result;
	}

	private Vector3 GetClosestCorePos(Vector3 mousePos)
	{
		Vector3 result = debuggingPos;
		float num = 1000f;
		foreach (Vector3 coresPosition in GetCoresPositions())
		{
			float num2 = Vector3.Distance(Holder.TransformPoint(coresPosition), mousePos);
			if (num2 < snappingDistance && num2 < num)
			{
				result = coresPosition;
				num = num2;
			}
		}
		return result;
	}

	public void SetShipSizeLimits()
	{
		buildingLimitX = Singleton<PlayerDataStore>.Instance.GetBuildingLimitX();
		buildingLimitY = Singleton<PlayerDataStore>.Instance.GetBuildingLimitY();
	}

	public List<Vector3> GetSurroundingEmpty(CoreController core, List<Vector3> Surroundings)
	{
		Vector3 corePos = GetCorePos(core);
		if (corePos == debuggingPos)
		{
			return new List<Vector3>();
		}
		List<Vector3> list = new List<Vector3>();
		foreach (Vector3 Surrounding in Surroundings)
		{
			Vector3 localPos = corePos + Surrounding;
			if (GetCoreAt(localPos) == null)
			{
				list.Add(Surrounding);
			}
		}
		return list;
	}

	public List<CoreController> GetSurroundingCoreControllers(CoreController core)
	{
		List<CoreController> list = new List<CoreController>();
		Vector3 corePos = GetCorePos(core);
		foreach (Vector3 surrounding in Surroundings)
		{
			Vector3 localPos = corePos + surrounding;
			CorePlacement corePlacement = GetCorePlacement(localPos);
			if (!MainCores.Contains(corePlacement) && corePlacement != null)
			{
				list.Add(corePlacement.coreController);
			}
		}
		return list;
	}

	public bool IsHoldingCore()
	{
		return holdedPiece != null;
	}

	public void ActivateSwitchs(int switchsNum = 1)
	{
		this.switchsNum = switchsNum;
	}

	public void ActivateMove(int moveCoreNum = 1)
	{
		this.moveCoreNum = moveCoreNum;
	}

	public void ActivateWall(int reinforceWall = 1)
	{
		this.reinforceWall = reinforceWall;
	}

	public void ActivateDuplicate(int duplicateNum = 1)
	{
		this.duplicateNum = duplicateNum;
	}

	public bool HasSwitches()
	{
		return switchsNum != 0;
	}

	public bool HasDuplicate()
	{
		return duplicateNum != 0;
	}

	public bool HasMoveCore()
	{
		return moveCoreNum != 0;
	}

	public bool HasReinforceWall()
	{
		return reinforceWall != 0;
	}

	public bool CanShowNextReward()
	{
		if (!IsHoldingCore() && !HasSwitches() && !HasDuplicate() && !HasMoveCore())
		{
			return !HasReinforceWall();
		}
		return false;
	}

	private void DestroyUnconnectedCores()
	{
		visitedCores = new List<CorePlacement>();
		unVisitedCores = new List<CorePlacement>();
		VisitCores(GetMainCoreNeighbors());
		foreach (CorePlacement currentCore in currentCores)
		{
			if (!visitedCores.Contains(currentCore) && !MainCores.Contains(currentCore))
			{
				unVisitedCores.Add(currentCore);
			}
		}
		foreach (CorePlacement unVisitedCore in unVisitedCores)
		{
			if (currentCores.Contains(unVisitedCore))
			{
				unVisitedCore.coreController.DestroyCore();
			}
		}
	}

	private bool MoveWillDisconnectCores(CoreController cc)
	{
		CorePlacement corePlacement = GetCorePlacement(cc);
		currentCores.Remove(corePlacement);
		visitedCores = new List<CorePlacement>();
		unVisitedCores = new List<CorePlacement>();
		VisitCores(GetMainCoreNeighbors());
		foreach (CorePlacement currentCore in currentCores)
		{
			if (!visitedCores.Contains(currentCore) && !MainCores.Contains(currentCore))
			{
				unVisitedCores.Add(currentCore);
			}
		}
		currentCores.Add(corePlacement);
		return unVisitedCores.Count != 0;
	}

	private void VisitCores(List<CorePlacement> corePlacementsList)
	{
		foreach (CorePlacement corePlacements in corePlacementsList)
		{
			VisitCore(corePlacements);
		}
	}

	private void VisitCore(CorePlacement cp)
	{
		if (!visitedCores.Contains(cp))
		{
			visitedCores.Add(cp);
			VisitCores(GetSurroundingCorePlacments(cp.coreController));
		}
	}

	private List<CorePlacement> GetMainCoreNeighbors()
	{
		List<CorePlacement> list = new List<CorePlacement>();
		foreach (Vector3 mainCoreNeighborsPo in mainCoreNeighborsPos)
		{
			CorePlacement corePlacement = GetCorePlacement(mainCoreNeighborsPo);
			if (corePlacement != null)
			{
				list.Add(corePlacement);
			}
		}
		return list;
	}

	private List<CorePlacement> GetSurroundingCorePlacments(CoreController core)
	{
		Vector3 corePos = GetCorePos(core);
		if (corePos == debuggingPos)
		{
			return new List<CorePlacement>();
		}
		List<CorePlacement> list = new List<CorePlacement>();
		foreach (Vector3 direction in Directions)
		{
			Vector3 localPos = corePos + direction;
			CorePlacement corePlacement = GetCorePlacement(localPos);
			if (corePlacement != null)
			{
				list.Add(corePlacement);
			}
		}
		return list;
	}

	private CorePlacement GetCorePlacement(GameObject obj)
	{
		foreach (CorePlacement currentCore in currentCores)
		{
			if (object.Equals(currentCore.coreObj, obj))
			{
				return currentCore;
			}
		}
		return null;
	}

	private CorePlacement GetCorePlacement(Vector3 localPos)
	{
		foreach (CorePlacement currentCore in currentCores)
		{
			if (object.Equals(currentCore.localPos, localPos))
			{
				return currentCore;
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

	private List<Vector3> GetCoresPositions(bool includeMainCore = false)
	{
		List<Vector3> list = new List<Vector3>();
		List<Vector3> list2 = new List<Vector3>
		{
			new Vector3(0f, 0f, 0f),
			new Vector3(1f, 0f, 0f),
			new Vector3(0f, 1f, 0f),
			new Vector3(1f, 1f, 0f)
		};
		foreach (CorePlacement currentCore in currentCores)
		{
			if (!includeMainCore)
			{
				if (!list2.Contains(currentCore.localPos))
				{
					list.Add(currentCore.localPos);
				}
			}
			else
			{
				list.Add(currentCore.localPos);
			}
		}
		return list;
	}

	private void HighLightCores(CoreController coreController)
	{
		SceneSingleton<PlayerCoresManager>.Instance.HighLightCores(coreController);
	}

	private void DisableHighLightCores()
	{
		SceneSingleton<PlayerCoresManager>.Instance.DisableHighLightCores();
	}

	public bool CanEndBuildMode()
	{
		if (IsHoldingCore())
		{
			return false;
		}
		if (HasDuplicate())
		{
			return false;
		}
		if (HasSwitches())
		{
			return false;
		}
		if (HasMoveCore())
		{
			return false;
		}
		if (HasReinforceWall())
		{
			return false;
		}
		return true;
	}
}
