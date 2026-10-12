using UnityEngine;
using UnityEngine.InputSystem;

public class InputManager : Singleton<InputManager>
{
	public bool isPlayerInputOn;

	public bool isInputOn;

	private bool isBuildingMode;

	private bool isGameEnded;

	[SerializeField]
	private bool isDebugOn;

	private bool moveRight;

	private bool moveLeft;

	private bool moveUp;

	private bool moveDown;

	private bool onShoot;

	private bool onBoost;

	private bool onRadar;

	public bool InvertAimX;

	public bool InvertAimY;

	public bool leftAim;

	public void EnableInput()
	{
		RefreshControllerSetting();
		isPlayerInputOn = true;
		isInputOn = true;
	}

	public void DisableInput()
	{
		isPlayerInputOn = false;
		isInputOn = false;
	}

	public void GameEndedEnableInput()
	{
		isGameEnded = true;
	}

	public void GameEndedDisableInput()
	{
		isGameEnded = false;
	}

	public void ResetInputManagerValues()
	{
		if (isDebugOn)
		{
			Debug.Log("ResetInputManagerValues");
		}
		onShoot = false;
		if (SceneSingleton<PlayerTurretManager>.Instance != null)
		{
			SceneSingleton<PlayerTurretManager>.Instance.ActivateTurret(onShoot);
		}
		onBoost = false;
		if (SceneSingleton<PlayerEngineBoostController>.Instance != null)
		{
			SceneSingleton<PlayerEngineBoostController>.Instance.UseEngine(onBoost);
		}
		onRadar = false;
		if (SceneSingleton<CameraManager>.Instance != null)
		{
			SceneSingleton<CameraManager>.Instance.SetRadarMode(onBoost);
		}
		if (SceneSingleton<PlayerMovement>.Instance != null)
		{
			moveRight = false;
			moveUp = false;
			moveDown = false;
			moveLeft = false;
			SceneSingleton<PlayerMovement>.Instance.MoveLeftClicked(down: false);
			SceneSingleton<PlayerMovement>.Instance.MoveRightClicked(down: false);
			SceneSingleton<PlayerMovement>.Instance.MoveDownClicked(down: false);
			SceneSingleton<PlayerMovement>.Instance.MoveUpClicked(down: false);
			SceneSingleton<PointerManager>.Instance.MoveLeftClicked(down: false);
			SceneSingleton<PointerManager>.Instance.MoveRightClicked(down: false);
			SceneSingleton<PointerManager>.Instance.MoveDownClicked(down: false);
			SceneSingleton<PointerManager>.Instance.MoveUpClicked(down: false);
		}
	}

	public void OnStartGame(InputAction.CallbackContext context)
	{
		if (context.performed)
		{
			if (SceneSingleton<LoadingPanelContorller>.Instance != null)
			{
				SceneSingleton<LoadingPanelContorller>.Instance.DisableLoadingScreen();
			}
			if (isDebugOn)
			{
				Debug.Log("OnStartGame Pressed");
			}
		}
	}

	public void OnNextTip(InputAction.CallbackContext context)
	{
		if (context.performed)
		{
			if (SceneSingleton<LoadingPanelContorller>.Instance != null)
			{
				SceneSingleton<LoadingPanelContorller>.Instance.NextTip();
			}
			if (isDebugOn)
			{
				Debug.Log("OnNextTip Pressed");
			}
		}
	}

	public void OnSkipIntro(InputAction.CallbackContext context)
	{
		if (context.performed)
		{
			if (SceneSingleton<IntroSceneManager>.Instance != null)
			{
				SceneSingleton<IntroSceneManager>.Instance.LoadMainMenuScene();
			}
			if (isDebugOn)
			{
				Debug.Log("OnSkipIntro Pressed");
			}
		}
	}

	public void OnMoveRight(InputAction.CallbackContext context)
	{
		if ((isInputOn || isBuildingMode) && context.performed)
		{
			moveRight = !moveRight;
			if (isBuildingMode)
			{
				SceneSingleton<PointerManager>.Instance.MoveRightClicked(moveRight);
			}
			else
			{
				SceneSingleton<PlayerMovement>.Instance.MoveRightClicked(moveRight);
			}
			if (isDebugOn)
			{
				Debug.Log("OnMoveRight Value: " + moveRight);
			}
		}
	}

	public void OnMoveLeft(InputAction.CallbackContext context)
	{
		if ((isInputOn || isBuildingMode) && context.performed)
		{
			moveLeft = !moveLeft;
			if (isBuildingMode)
			{
				SceneSingleton<PointerManager>.Instance.MoveLeftClicked(moveLeft);
			}
			else
			{
				SceneSingleton<PlayerMovement>.Instance.MoveLeftClicked(moveLeft);
			}
			if (isDebugOn)
			{
				Debug.Log("OnMoveLeft Value: " + moveLeft);
			}
		}
	}

	public void OnMoveUp(InputAction.CallbackContext context)
	{
		if ((isInputOn || isBuildingMode) && context.performed)
		{
			moveUp = !moveUp;
			if (isBuildingMode)
			{
				SceneSingleton<PointerManager>.Instance.MoveUpClicked(moveUp);
			}
			else
			{
				SceneSingleton<PlayerMovement>.Instance.MoveUpClicked(moveUp);
			}
			if (isDebugOn)
			{
				Debug.Log("OnMoveUp Value: " + moveUp);
			}
		}
	}

	public void OnMoveDown(InputAction.CallbackContext context)
	{
		if ((isInputOn || isBuildingMode) && context.performed)
		{
			moveDown = !moveDown;
			if (isBuildingMode)
			{
				SceneSingleton<PointerManager>.Instance.MoveDownClicked(moveDown);
			}
			else
			{
				SceneSingleton<PlayerMovement>.Instance.MoveDownClicked(moveDown);
			}
			if (isDebugOn)
			{
				Debug.Log("OnMoveDown Value: " + moveDown);
			}
		}
	}

	public void OnShoot(InputAction.CallbackContext context)
	{
		if (isInputOn && context.performed)
		{
			onShoot = !onShoot;
			SceneSingleton<PlayerTurretManager>.Instance.ActivateTurret(onShoot);
			if (isDebugOn)
			{
				Debug.Log("OnShoot Value: " + onShoot);
			}
		}
	}

	public void OnAimLeft(InputAction.CallbackContext context)
	{
		if (!isGameEnded && !leftAim)
		{
			ComputeAim(context.ReadValue<Vector2>());
			if (isDebugOn)
			{
				Debug.Log("OnAim Clicked " + context.ReadValue<Vector2>().ToString());
			}
		}
	}

	public void OnAimRight(InputAction.CallbackContext context)
	{
		if (!isGameEnded && leftAim)
		{
			ComputeAim(context.ReadValue<Vector2>());
			if (isDebugOn)
			{
				Debug.Log("OnAim Clicked " + context.ReadValue<Vector2>().ToString());
			}
		}
	}

	public void ComputeAim(Vector2 dir)
	{
		if (InvertAimX)
		{
			dir.x *= -1f;
		}
		if (InvertAimY)
		{
			dir.y *= -1f;
		}
		SceneSingleton<PlayerTurretManager>.Instance.SetAimDirection(dir);
	}

	public void OnBoost(InputAction.CallbackContext context)
	{
		if (isInputOn)
		{
			if (context.performed)
			{
				onBoost = !onBoost;
			}
			SceneSingleton<PlayerEngineBoostController>.Instance.UseEngine(onBoost);
			if (isDebugOn)
			{
				Debug.Log("OnBoost Value: " + onBoost);
			}
		}
	}

	public void OnRadar(InputAction.CallbackContext context)
	{
		if (isInputOn)
		{
			if (context.performed)
			{
				onRadar = !onRadar;
			}
			SceneSingleton<CameraManager>.Instance.SetRadarMode(onRadar);
			if (isDebugOn)
			{
				Debug.Log("OnRadar Value: " + onRadar);
			}
		}
	}

	public void OnBuild(InputAction.CallbackContext context)
	{
		if (isBuildingMode && context.performed)
		{
			SceneSingleton<PlayerBuildingManager>.Instance.LeftMouseClick();
			if (isDebugOn)
			{
				Debug.Log("OnBuild Clicked");
			}
		}
	}

	public void OnOpenBuild(InputAction.CallbackContext context)
	{
		if (!isBuildingMode && context.performed)
		{
			if (SceneSingleton<CameraManager>.Instance != null && !SceneSingleton<CameraManager>.Instance.isFollowingTarget && SceneSingleton<RewardSystemManager>.Instance.IsRewardAvilable())
			{
				SceneSingleton<GameManager>.Instance.OpenBuildMode();
			}
			if (isDebugOn)
			{
				Debug.Log("OnBuild Clicked");
			}
		}
	}

	public void OnBack(InputAction.CallbackContext context)
	{
		if (!isGameEnded && isInputOn && context.performed)
		{
			if (SceneSingleton<GameManager>.Instance != null)
			{
				SceneSingleton<GameManager>.Instance.PauseKeyPressed();
			}
			if (isDebugOn)
			{
				Debug.Log("OnBack Clicked");
			}
		}
	}

	public void OnBackUI(InputAction.CallbackContext context)
	{
		if (!isGameEnded && context.started)
		{
			if (SceneSingleton<GameManager>.Instance != null)
			{
				SceneSingleton<GameManager>.Instance.unPauseGame();
			}
			if (SceneSingleton<MainMenuManager>.Instance != null)
			{
				SceneSingleton<MainMenuManager>.Instance.PressBack();
			}
			if (SceneSingleton<UpgradeTreeManager>.Instance != null)
			{
				SceneSingleton<UpgradeTreeManager>.Instance.BackNode();
			}
			if (isDebugOn)
			{
				Debug.Log("OnBackUI Clicked");
			}
		}
	}

	public void OnControlsChangedEvent(PlayerInput player)
	{
		if (Singleton<InputDataStore>.Instance != null)
		{
			Singleton<InputDataStore>.Instance.OnControlsChangedEvent(player);
		}
	}

	public void ActivateBuildMode()
	{
		isBuildingMode = true;
		isPlayerInputOn = false;
	}

	public void EndBuildMode()
	{
		isBuildingMode = false;
		isPlayerInputOn = true;
	}

	private void RefreshControllerSetting()
	{
		InvertAimX = SaveSystem.GetInvertAimXSetting();
		InvertAimY = SaveSystem.GetInvertAimYSetting();
		leftAim = SaveSystem.GetSwitchAimSetting();
	}
}
