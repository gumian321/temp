using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Utilities;

public class PlayerInputActions : IInputActionCollection2, IInputActionCollection, IEnumerable<InputAction>, IEnumerable, IDisposable
{
	public struct LoadingActions
	{
		private PlayerInputActions m_Wrapper;

		public InputAction SkipIntro => m_Wrapper.m_Loading_SkipIntro;

		public InputAction StartGame => m_Wrapper.m_Loading_StartGame;

		public InputAction NextTip => m_Wrapper.m_Loading_NextTip;

		public bool enabled => Get().enabled;

		public LoadingActions(PlayerInputActions wrapper)
		{
			m_Wrapper = wrapper;
		}

		public InputActionMap Get()
		{
			return m_Wrapper.m_Loading;
		}

		public void Enable()
		{
			Get().Enable();
		}

		public void Disable()
		{
			Get().Disable();
		}

		public static implicit operator InputActionMap(LoadingActions set)
		{
			return set.Get();
		}

		public void AddCallbacks(ILoadingActions instance)
		{
			if (instance != null && !m_Wrapper.m_LoadingActionsCallbackInterfaces.Contains(instance))
			{
				m_Wrapper.m_LoadingActionsCallbackInterfaces.Add(instance);
				SkipIntro.started += instance.OnSkipIntro;
				SkipIntro.performed += instance.OnSkipIntro;
				SkipIntro.canceled += instance.OnSkipIntro;
				StartGame.started += instance.OnStartGame;
				StartGame.performed += instance.OnStartGame;
				StartGame.canceled += instance.OnStartGame;
				NextTip.started += instance.OnNextTip;
				NextTip.performed += instance.OnNextTip;
				NextTip.canceled += instance.OnNextTip;
			}
		}

		private void UnregisterCallbacks(ILoadingActions instance)
		{
			SkipIntro.started -= instance.OnSkipIntro;
			SkipIntro.performed -= instance.OnSkipIntro;
			SkipIntro.canceled -= instance.OnSkipIntro;
			StartGame.started -= instance.OnStartGame;
			StartGame.performed -= instance.OnStartGame;
			StartGame.canceled -= instance.OnStartGame;
			NextTip.started -= instance.OnNextTip;
			NextTip.performed -= instance.OnNextTip;
			NextTip.canceled -= instance.OnNextTip;
		}

		public void RemoveCallbacks(ILoadingActions instance)
		{
			if (m_Wrapper.m_LoadingActionsCallbackInterfaces.Remove(instance))
			{
				UnregisterCallbacks(instance);
			}
		}

		public void SetCallbacks(ILoadingActions instance)
		{
			foreach (ILoadingActions loadingActionsCallbackInterface in m_Wrapper.m_LoadingActionsCallbackInterfaces)
			{
				UnregisterCallbacks(loadingActionsCallbackInterface);
			}
			m_Wrapper.m_LoadingActionsCallbackInterfaces.Clear();
			AddCallbacks(instance);
		}
	}

	public struct GameplayActions
	{
		private PlayerInputActions m_Wrapper;

		public InputAction MenuBack => m_Wrapper.m_Gameplay_MenuBack;

		public InputAction MoveUp => m_Wrapper.m_Gameplay_MoveUp;

		public InputAction MoveDown => m_Wrapper.m_Gameplay_MoveDown;

		public InputAction MoveRight => m_Wrapper.m_Gameplay_MoveRight;

		public InputAction MoveLeft => m_Wrapper.m_Gameplay_MoveLeft;

		public InputAction Shoot => m_Wrapper.m_Gameplay_Shoot;

		public InputAction Build => m_Wrapper.m_Gameplay_Build;

		public InputAction OpenBuild => m_Wrapper.m_Gameplay_OpenBuild;

		public InputAction Radar => m_Wrapper.m_Gameplay_Radar;

		public InputAction Boost => m_Wrapper.m_Gameplay_Boost;

		public InputAction AimRight => m_Wrapper.m_Gameplay_AimRight;

		public InputAction AimLeft => m_Wrapper.m_Gameplay_AimLeft;

		public bool enabled => Get().enabled;

		public GameplayActions(PlayerInputActions wrapper)
		{
			m_Wrapper = wrapper;
		}

		public InputActionMap Get()
		{
			return m_Wrapper.m_Gameplay;
		}

		public void Enable()
		{
			Get().Enable();
		}

		public void Disable()
		{
			Get().Disable();
		}

		public static implicit operator InputActionMap(GameplayActions set)
		{
			return set.Get();
		}

		public void AddCallbacks(IGameplayActions instance)
		{
			if (instance != null && !m_Wrapper.m_GameplayActionsCallbackInterfaces.Contains(instance))
			{
				m_Wrapper.m_GameplayActionsCallbackInterfaces.Add(instance);
				MenuBack.started += instance.OnMenuBack;
				MenuBack.performed += instance.OnMenuBack;
				MenuBack.canceled += instance.OnMenuBack;
				MoveUp.started += instance.OnMoveUp;
				MoveUp.performed += instance.OnMoveUp;
				MoveUp.canceled += instance.OnMoveUp;
				MoveDown.started += instance.OnMoveDown;
				MoveDown.performed += instance.OnMoveDown;
				MoveDown.canceled += instance.OnMoveDown;
				MoveRight.started += instance.OnMoveRight;
				MoveRight.performed += instance.OnMoveRight;
				MoveRight.canceled += instance.OnMoveRight;
				MoveLeft.started += instance.OnMoveLeft;
				MoveLeft.performed += instance.OnMoveLeft;
				MoveLeft.canceled += instance.OnMoveLeft;
				Shoot.started += instance.OnShoot;
				Shoot.performed += instance.OnShoot;
				Shoot.canceled += instance.OnShoot;
				Build.started += instance.OnBuild;
				Build.performed += instance.OnBuild;
				Build.canceled += instance.OnBuild;
				OpenBuild.started += instance.OnOpenBuild;
				OpenBuild.performed += instance.OnOpenBuild;
				OpenBuild.canceled += instance.OnOpenBuild;
				Radar.started += instance.OnRadar;
				Radar.performed += instance.OnRadar;
				Radar.canceled += instance.OnRadar;
				Boost.started += instance.OnBoost;
				Boost.performed += instance.OnBoost;
				Boost.canceled += instance.OnBoost;
				AimRight.started += instance.OnAimRight;
				AimRight.performed += instance.OnAimRight;
				AimRight.canceled += instance.OnAimRight;
				AimLeft.started += instance.OnAimLeft;
				AimLeft.performed += instance.OnAimLeft;
				AimLeft.canceled += instance.OnAimLeft;
			}
		}

		private void UnregisterCallbacks(IGameplayActions instance)
		{
			MenuBack.started -= instance.OnMenuBack;
			MenuBack.performed -= instance.OnMenuBack;
			MenuBack.canceled -= instance.OnMenuBack;
			MoveUp.started -= instance.OnMoveUp;
			MoveUp.performed -= instance.OnMoveUp;
			MoveUp.canceled -= instance.OnMoveUp;
			MoveDown.started -= instance.OnMoveDown;
			MoveDown.performed -= instance.OnMoveDown;
			MoveDown.canceled -= instance.OnMoveDown;
			MoveRight.started -= instance.OnMoveRight;
			MoveRight.performed -= instance.OnMoveRight;
			MoveRight.canceled -= instance.OnMoveRight;
			MoveLeft.started -= instance.OnMoveLeft;
			MoveLeft.performed -= instance.OnMoveLeft;
			MoveLeft.canceled -= instance.OnMoveLeft;
			Shoot.started -= instance.OnShoot;
			Shoot.performed -= instance.OnShoot;
			Shoot.canceled -= instance.OnShoot;
			Build.started -= instance.OnBuild;
			Build.performed -= instance.OnBuild;
			Build.canceled -= instance.OnBuild;
			OpenBuild.started -= instance.OnOpenBuild;
			OpenBuild.performed -= instance.OnOpenBuild;
			OpenBuild.canceled -= instance.OnOpenBuild;
			Radar.started -= instance.OnRadar;
			Radar.performed -= instance.OnRadar;
			Radar.canceled -= instance.OnRadar;
			Boost.started -= instance.OnBoost;
			Boost.performed -= instance.OnBoost;
			Boost.canceled -= instance.OnBoost;
			AimRight.started -= instance.OnAimRight;
			AimRight.performed -= instance.OnAimRight;
			AimRight.canceled -= instance.OnAimRight;
			AimLeft.started -= instance.OnAimLeft;
			AimLeft.performed -= instance.OnAimLeft;
			AimLeft.canceled -= instance.OnAimLeft;
		}

		public void RemoveCallbacks(IGameplayActions instance)
		{
			if (m_Wrapper.m_GameplayActionsCallbackInterfaces.Remove(instance))
			{
				UnregisterCallbacks(instance);
			}
		}

		public void SetCallbacks(IGameplayActions instance)
		{
			foreach (IGameplayActions gameplayActionsCallbackInterface in m_Wrapper.m_GameplayActionsCallbackInterfaces)
			{
				UnregisterCallbacks(gameplayActionsCallbackInterface);
			}
			m_Wrapper.m_GameplayActionsCallbackInterfaces.Clear();
			AddCallbacks(instance);
		}
	}

	public struct UIActions
	{
		private PlayerInputActions m_Wrapper;

		public InputAction MenuBack => m_Wrapper.m_UI_MenuBack;

		public InputAction TrackedDeviceOrientation => m_Wrapper.m_UI_TrackedDeviceOrientation;

		public InputAction TrackedDevicePosition => m_Wrapper.m_UI_TrackedDevicePosition;

		public InputAction RightClick => m_Wrapper.m_UI_RightClick;

		public InputAction MiddleClick => m_Wrapper.m_UI_MiddleClick;

		public InputAction ScrollWheel => m_Wrapper.m_UI_ScrollWheel;

		public InputAction Click => m_Wrapper.m_UI_Click;

		public InputAction Point => m_Wrapper.m_UI_Point;

		public InputAction Cancel => m_Wrapper.m_UI_Cancel;

		public InputAction Submit => m_Wrapper.m_UI_Submit;

		public InputAction Navigate => m_Wrapper.m_UI_Navigate;

		public bool enabled => Get().enabled;

		public UIActions(PlayerInputActions wrapper)
		{
			m_Wrapper = wrapper;
		}

		public InputActionMap Get()
		{
			return m_Wrapper.m_UI;
		}

		public void Enable()
		{
			Get().Enable();
		}

		public void Disable()
		{
			Get().Disable();
		}

		public static implicit operator InputActionMap(UIActions set)
		{
			return set.Get();
		}

		public void AddCallbacks(IUIActions instance)
		{
			if (instance != null && !m_Wrapper.m_UIActionsCallbackInterfaces.Contains(instance))
			{
				m_Wrapper.m_UIActionsCallbackInterfaces.Add(instance);
				MenuBack.started += instance.OnMenuBack;
				MenuBack.performed += instance.OnMenuBack;
				MenuBack.canceled += instance.OnMenuBack;
				TrackedDeviceOrientation.started += instance.OnTrackedDeviceOrientation;
				TrackedDeviceOrientation.performed += instance.OnTrackedDeviceOrientation;
				TrackedDeviceOrientation.canceled += instance.OnTrackedDeviceOrientation;
				TrackedDevicePosition.started += instance.OnTrackedDevicePosition;
				TrackedDevicePosition.performed += instance.OnTrackedDevicePosition;
				TrackedDevicePosition.canceled += instance.OnTrackedDevicePosition;
				RightClick.started += instance.OnRightClick;
				RightClick.performed += instance.OnRightClick;
				RightClick.canceled += instance.OnRightClick;
				MiddleClick.started += instance.OnMiddleClick;
				MiddleClick.performed += instance.OnMiddleClick;
				MiddleClick.canceled += instance.OnMiddleClick;
				ScrollWheel.started += instance.OnScrollWheel;
				ScrollWheel.performed += instance.OnScrollWheel;
				ScrollWheel.canceled += instance.OnScrollWheel;
				Click.started += instance.OnClick;
				Click.performed += instance.OnClick;
				Click.canceled += instance.OnClick;
				Point.started += instance.OnPoint;
				Point.performed += instance.OnPoint;
				Point.canceled += instance.OnPoint;
				Cancel.started += instance.OnCancel;
				Cancel.performed += instance.OnCancel;
				Cancel.canceled += instance.OnCancel;
				Submit.started += instance.OnSubmit;
				Submit.performed += instance.OnSubmit;
				Submit.canceled += instance.OnSubmit;
				Navigate.started += instance.OnNavigate;
				Navigate.performed += instance.OnNavigate;
				Navigate.canceled += instance.OnNavigate;
			}
		}

		private void UnregisterCallbacks(IUIActions instance)
		{
			MenuBack.started -= instance.OnMenuBack;
			MenuBack.performed -= instance.OnMenuBack;
			MenuBack.canceled -= instance.OnMenuBack;
			TrackedDeviceOrientation.started -= instance.OnTrackedDeviceOrientation;
			TrackedDeviceOrientation.performed -= instance.OnTrackedDeviceOrientation;
			TrackedDeviceOrientation.canceled -= instance.OnTrackedDeviceOrientation;
			TrackedDevicePosition.started -= instance.OnTrackedDevicePosition;
			TrackedDevicePosition.performed -= instance.OnTrackedDevicePosition;
			TrackedDevicePosition.canceled -= instance.OnTrackedDevicePosition;
			RightClick.started -= instance.OnRightClick;
			RightClick.performed -= instance.OnRightClick;
			RightClick.canceled -= instance.OnRightClick;
			MiddleClick.started -= instance.OnMiddleClick;
			MiddleClick.performed -= instance.OnMiddleClick;
			MiddleClick.canceled -= instance.OnMiddleClick;
			ScrollWheel.started -= instance.OnScrollWheel;
			ScrollWheel.performed -= instance.OnScrollWheel;
			ScrollWheel.canceled -= instance.OnScrollWheel;
			Click.started -= instance.OnClick;
			Click.performed -= instance.OnClick;
			Click.canceled -= instance.OnClick;
			Point.started -= instance.OnPoint;
			Point.performed -= instance.OnPoint;
			Point.canceled -= instance.OnPoint;
			Cancel.started -= instance.OnCancel;
			Cancel.performed -= instance.OnCancel;
			Cancel.canceled -= instance.OnCancel;
			Submit.started -= instance.OnSubmit;
			Submit.performed -= instance.OnSubmit;
			Submit.canceled -= instance.OnSubmit;
			Navigate.started -= instance.OnNavigate;
			Navigate.performed -= instance.OnNavigate;
			Navigate.canceled -= instance.OnNavigate;
		}

		public void RemoveCallbacks(IUIActions instance)
		{
			if (m_Wrapper.m_UIActionsCallbackInterfaces.Remove(instance))
			{
				UnregisterCallbacks(instance);
			}
		}

		public void SetCallbacks(IUIActions instance)
		{
			foreach (IUIActions uIActionsCallbackInterface in m_Wrapper.m_UIActionsCallbackInterfaces)
			{
				UnregisterCallbacks(uIActionsCallbackInterface);
			}
			m_Wrapper.m_UIActionsCallbackInterfaces.Clear();
			AddCallbacks(instance);
		}
	}

	public interface ILoadingActions
	{
		void OnSkipIntro(InputAction.CallbackContext context);

		void OnStartGame(InputAction.CallbackContext context);

		void OnNextTip(InputAction.CallbackContext context);
	}

	public interface IGameplayActions
	{
		void OnMenuBack(InputAction.CallbackContext context);

		void OnMoveUp(InputAction.CallbackContext context);

		void OnMoveDown(InputAction.CallbackContext context);

		void OnMoveRight(InputAction.CallbackContext context);

		void OnMoveLeft(InputAction.CallbackContext context);

		void OnShoot(InputAction.CallbackContext context);

		void OnBuild(InputAction.CallbackContext context);

		void OnOpenBuild(InputAction.CallbackContext context);

		void OnRadar(InputAction.CallbackContext context);

		void OnBoost(InputAction.CallbackContext context);

		void OnAimRight(InputAction.CallbackContext context);

		void OnAimLeft(InputAction.CallbackContext context);
	}

	public interface IUIActions
	{
		void OnMenuBack(InputAction.CallbackContext context);

		void OnTrackedDeviceOrientation(InputAction.CallbackContext context);

		void OnTrackedDevicePosition(InputAction.CallbackContext context);

		void OnRightClick(InputAction.CallbackContext context);

		void OnMiddleClick(InputAction.CallbackContext context);

		void OnScrollWheel(InputAction.CallbackContext context);

		void OnClick(InputAction.CallbackContext context);

		void OnPoint(InputAction.CallbackContext context);

		void OnCancel(InputAction.CallbackContext context);

		void OnSubmit(InputAction.CallbackContext context);

		void OnNavigate(InputAction.CallbackContext context);
	}

	private readonly InputActionMap m_Loading;

	private List<ILoadingActions> m_LoadingActionsCallbackInterfaces = new List<ILoadingActions>();

	private readonly InputAction m_Loading_SkipIntro;

	private readonly InputAction m_Loading_StartGame;

	private readonly InputAction m_Loading_NextTip;

	private readonly InputActionMap m_Gameplay;

	private List<IGameplayActions> m_GameplayActionsCallbackInterfaces = new List<IGameplayActions>();

	private readonly InputAction m_Gameplay_MenuBack;

	private readonly InputAction m_Gameplay_MoveUp;

	private readonly InputAction m_Gameplay_MoveDown;

	private readonly InputAction m_Gameplay_MoveRight;

	private readonly InputAction m_Gameplay_MoveLeft;

	private readonly InputAction m_Gameplay_Shoot;

	private readonly InputAction m_Gameplay_Build;

	private readonly InputAction m_Gameplay_OpenBuild;

	private readonly InputAction m_Gameplay_Radar;

	private readonly InputAction m_Gameplay_Boost;

	private readonly InputAction m_Gameplay_AimRight;

	private readonly InputAction m_Gameplay_AimLeft;

	private readonly InputActionMap m_UI;

	private List<IUIActions> m_UIActionsCallbackInterfaces = new List<IUIActions>();

	private readonly InputAction m_UI_MenuBack;

	private readonly InputAction m_UI_TrackedDeviceOrientation;

	private readonly InputAction m_UI_TrackedDevicePosition;

	private readonly InputAction m_UI_RightClick;

	private readonly InputAction m_UI_MiddleClick;

	private readonly InputAction m_UI_ScrollWheel;

	private readonly InputAction m_UI_Click;

	private readonly InputAction m_UI_Point;

	private readonly InputAction m_UI_Cancel;

	private readonly InputAction m_UI_Submit;

	private readonly InputAction m_UI_Navigate;

	private int m_KeyboardandMouseSchemeIndex = -1;

	private int m_GamepadSchemeIndex = -1;

	public InputActionAsset asset { get; }

	public InputBinding? bindingMask
	{
		get
		{
			return asset.bindingMask;
		}
		set
		{
			asset.bindingMask = value;
		}
	}

	public ReadOnlyArray<InputDevice>? devices
	{
		get
		{
			return asset.devices;
		}
		set
		{
			asset.devices = value;
		}
	}

	public ReadOnlyArray<InputControlScheme> controlSchemes => asset.controlSchemes;

	public IEnumerable<InputBinding> bindings => asset.bindings;

	public LoadingActions Loading => new LoadingActions(this);

	public GameplayActions Gameplay => new GameplayActions(this);

	public UIActions UI => new UIActions(this);

	public InputControlScheme KeyboardandMouseScheme
	{
		get
		{
			if (m_KeyboardandMouseSchemeIndex == -1)
			{
				m_KeyboardandMouseSchemeIndex = asset.FindControlSchemeIndex("Keyboard and Mouse");
			}
			return asset.controlSchemes[m_KeyboardandMouseSchemeIndex];
		}
	}

	public InputControlScheme GamepadScheme
	{
		get
		{
			if (m_GamepadSchemeIndex == -1)
			{
				m_GamepadSchemeIndex = asset.FindControlSchemeIndex("Gamepad");
			}
			return asset.controlSchemes[m_GamepadSchemeIndex];
		}
	}

	public PlayerInputActions()
	{
		asset = InputActionAsset.FromJson("{\r\n    \"name\": \"PlayerInputActions\",\r\n    \"maps\": [\r\n        {\r\n            \"name\": \"Loading\",\r\n            \"id\": \"e04189a7-081a-4de6-8766-9b60ef170cfc\",\r\n            \"actions\": [\r\n                {\r\n                    \"name\": \"SkipIntro\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"f3f17152-87a4-44d9-9c62-06a2affede8a\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"StartGame\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"5464bbbc-adc5-4ea5-b6e9-e67e07135cda\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"Press\",\r\n                    \"initialStateCheck\": true\r\n                },\r\n                {\r\n                    \"name\": \"NextTip\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"d1ee0fc9-c0d4-47f1-860e-e86c38c7c7fd\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"AxisDeadzone\",\r\n                    \"interactions\": \"Press\",\r\n                    \"initialStateCheck\": true\r\n                }\r\n            ],\r\n            \"bindings\": [\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"54387372-a702-4135-8404-823fc016032b\",\r\n                    \"path\": \"*/{Back}\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"SkipIntro\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"1d5f6030-7b1f-485a-ab16-c025535995ae\",\r\n                    \"path\": \"*/{Cancel}\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"SkipIntro\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"4c48ae91-8aa3-48a3-a27a-e34092eb9783\",\r\n                    \"path\": \"*/{Forward}\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"SkipIntro\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"f4609752-7732-4ff6-8cb6-54fc1ce4d9e9\",\r\n                    \"path\": \"*/{Menu}\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"SkipIntro\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"8b341576-907d-4de5-a5ad-89232ab6cfc2\",\r\n                    \"path\": \"*/{Submit}\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"SkipIntro\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"d8ccc692-4937-497e-8707-f635df5f59c8\",\r\n                    \"path\": \"<Keyboard>/d\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"NextTip\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"1832d152-db00-4e6d-be9c-479ed8f8a3f3\",\r\n                    \"path\": \"<Gamepad>/leftStick/right\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"NextTip\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"d384622a-c075-45c4-889c-937eef8741ac\",\r\n                    \"path\": \"<Mouse>/leftButton\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"StartGame\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"a611a893-72db-4ebd-8aa5-da682c8c07fa\",\r\n                    \"path\": \"<Gamepad>/rightTrigger\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"StartGame\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                }\r\n            ]\r\n        },\r\n        {\r\n            \"name\": \"Gameplay\",\r\n            \"id\": \"6f29a9ef-d45a-45b3-a047-693dd8d85c25\",\r\n            \"actions\": [\r\n                {\r\n                    \"name\": \"MenuBack\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"f8b14993-2f3b-4012-99ba-ce9533c19cfc\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"Press\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"MoveUp\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"6bbc8674-e498-4e3f-96be-461e0abaa462\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"AxisDeadzone\",\r\n                    \"interactions\": \"Press(behavior=2)\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"MoveDown\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"e95a106b-9b33-416e-8ec1-fa8f932bf9ac\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"AxisDeadzone\",\r\n                    \"interactions\": \"Press(behavior=2)\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"MoveRight\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"13642cec-9b0d-4e8e-97da-a170ac83e56f\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"AxisDeadzone\",\r\n                    \"interactions\": \"Press(behavior=2)\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"MoveLeft\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"e27f3404-7737-43f4-9f31-93655cf89797\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"AxisDeadzone\",\r\n                    \"interactions\": \"Press(behavior=2)\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"Shoot\",\r\n                    \"type\": \"Value\",\r\n                    \"id\": \"a5b92b75-3bcd-4be2-8a61-e1cc596839ad\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"AxisDeadzone\",\r\n                    \"interactions\": \"Press(behavior=2)\",\r\n                    \"initialStateCheck\": true\r\n                },\r\n                {\r\n                    \"name\": \"Build\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"52dc4c55-5113-49aa-8945-c319362c9d99\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"AxisDeadzone\",\r\n                    \"interactions\": \"Press\",\r\n                    \"initialStateCheck\": true\r\n                },\r\n                {\r\n                    \"name\": \"OpenBuild\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"da8799ac-dccc-40ff-bbeb-96c3f1706499\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"AxisDeadzone\",\r\n                    \"interactions\": \"Press\",\r\n                    \"initialStateCheck\": true\r\n                },\r\n                {\r\n                    \"name\": \"Radar\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"9ca7c3d9-1c17-43cf-af1b-6e14c178317d\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"AxisDeadzone\",\r\n                    \"interactions\": \"Press(behavior=2)\",\r\n                    \"initialStateCheck\": true\r\n                },\r\n                {\r\n                    \"name\": \"Boost\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"83c69f1e-6dbb-451e-9172-69988bae4244\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"AxisDeadzone\",\r\n                    \"interactions\": \"Press(behavior=2)\",\r\n                    \"initialStateCheck\": true\r\n                },\r\n                {\r\n                    \"name\": \"AimRight\",\r\n                    \"type\": \"Value\",\r\n                    \"id\": \"673e48bd-4633-420a-8d42-84deb93328e2\",\r\n                    \"expectedControlType\": \"Vector2\",\r\n                    \"processors\": \"StickDeadzone\",\r\n                    \"interactions\": \"\",\r\n                    \"initialStateCheck\": true\r\n                },\r\n                {\r\n                    \"name\": \"AimLeft\",\r\n                    \"type\": \"Value\",\r\n                    \"id\": \"f5c208dd-1409-471a-b401-0fc265d36077\",\r\n                    \"expectedControlType\": \"Vector2\",\r\n                    \"processors\": \"StickDeadzone\",\r\n                    \"interactions\": \"\",\r\n                    \"initialStateCheck\": true\r\n                }\r\n            ],\r\n            \"bindings\": [\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"2de9f5a0-ceeb-4a1e-a0fb-ba70767778c0\",\r\n                    \"path\": \"<Mouse>/leftButton\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"Shoot\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"5007a742-07e9-4aea-906c-f5afbfa4ae53\",\r\n                    \"path\": \"<Gamepad>/rightTrigger\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"Shoot\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"c4bb6924-02ba-44b5-8f75-55c9752f5bee\",\r\n                    \"path\": \"<Keyboard>/a\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"MoveLeft\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"e0670709-2176-4214-af7d-7ff3c344e42c\",\r\n                    \"path\": \"<Gamepad>/leftStick/left\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"MoveLeft\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"cac8048b-5de3-4f70-9dc7-a61d2158a790\",\r\n                    \"path\": \"<Keyboard>/d\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"MoveRight\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"b9c25917-3fd3-46af-a244-08dd0c724dd1\",\r\n                    \"path\": \"<Gamepad>/leftStick/right\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"MoveRight\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"06cbf416-31ad-41c1-9d6d-3298148b26a8\",\r\n                    \"path\": \"<Mouse>/rightButton\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"Radar\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"1a94a9ce-845c-4f78-9dc1-71daae3e4636\",\r\n                    \"path\": \"<Gamepad>/buttonSouth\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"Radar\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"d0146562-efd7-49eb-80b4-325e33cfacf2\",\r\n                    \"path\": \"<Keyboard>/w\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"MoveUp\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"caaffde4-c5f7-4a7f-854a-090b4b224cf6\",\r\n                    \"path\": \"<Gamepad>/leftStick/up\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"MoveUp\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"9a9f64fb-34ea-49d2-a93b-b6affc740e7f\",\r\n                    \"path\": \"<Keyboard>/s\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"MoveDown\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"412b746b-23c8-4498-9761-36c7423cc6fd\",\r\n                    \"path\": \"<Gamepad>/leftStick/down\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"MoveDown\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"b07f904e-9449-4eec-b919-c16a7aa78b9a\",\r\n                    \"path\": \"<Keyboard>/leftShift\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"Boost\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"3bfa8c46-1934-4c38-9261-a7d57cc3a2f7\",\r\n                    \"path\": \"<Gamepad>/leftTrigger\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"Boost\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"f30bfb4d-7f15-4883-8b68-7f26a177aee8\",\r\n                    \"path\": \"<Mouse>/leftButton\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"Build\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"5fa3c418-8aa8-4a1b-9b99-bfd616225cbe\",\r\n                    \"path\": \"<Keyboard>/space\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"Build\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"f8253f03-78cc-4cee-a5cd-0566361862fb\",\r\n                    \"path\": \"<Gamepad>/rightTrigger\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"Build\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"4cd47cc3-6ca8-4630-bb6e-f77dc8be2968\",\r\n                    \"path\": \"<Gamepad>/buttonSouth\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"Build\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"ee15175d-61a7-46d1-8749-c3fdceae7a6f\",\r\n                    \"path\": \"<Keyboard>/e\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"OpenBuild\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"dce58b1d-4e52-45e4-a391-e2a17d082d8e\",\r\n                    \"path\": \"<Gamepad>/buttonEast\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"OpenBuild\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"36d7bb90-203a-45ff-87d5-ac777d4ff1bc\",\r\n                    \"path\": \"<Keyboard>/escape\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"MenuBack\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"1bb6caa9-13ac-4b87-aed5-e66640d53597\",\r\n                    \"path\": \"<Gamepad>/start\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"MenuBack\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"261f958f-29ef-40eb-b7cc-90a7663b5f7d\",\r\n                    \"path\": \"<Gamepad>/select\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"MenuBack\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"2D Vector\",\r\n                    \"id\": \"c7e73ff5-469d-4062-80a2-8088df64a0a0\",\r\n                    \"path\": \"2DVector(mode=2)\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"AimRight\",\r\n                    \"isComposite\": true,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"up\",\r\n                    \"id\": \"d28cab7c-14c4-48ae-b4de-063114b17098\",\r\n                    \"path\": \"<Gamepad>/rightStick/up\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"AimRight\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"down\",\r\n                    \"id\": \"4dda4f7e-92cf-4a85-b145-67b9a2f5b6bd\",\r\n                    \"path\": \"<Gamepad>/rightStick/down\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"AimRight\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"left\",\r\n                    \"id\": \"f11bc9fa-11a5-45e2-b2b6-c943cec7ec6e\",\r\n                    \"path\": \"<Gamepad>/rightStick/left\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"AimRight\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"right\",\r\n                    \"id\": \"cdc9e5d2-5b40-4c6d-a29d-5f837c202b81\",\r\n                    \"path\": \"<Gamepad>/rightStick/right\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"AimRight\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"2D Vector\",\r\n                    \"id\": \"740dc6fe-dea5-4f80-aa77-482bd85464b8\",\r\n                    \"path\": \"2DVector(mode=2)\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"AimLeft\",\r\n                    \"isComposite\": true,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"up\",\r\n                    \"id\": \"14ebc2dd-20f2-4ec7-97b9-f1de514500ce\",\r\n                    \"path\": \"<Gamepad>/leftStick/up\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"AimLeft\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"down\",\r\n                    \"id\": \"a96de686-9497-4c82-b8d0-3a416bb5ee31\",\r\n                    \"path\": \"<Gamepad>/leftStick/down\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"AimLeft\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"left\",\r\n                    \"id\": \"6cace8b9-4384-4b1a-a0d7-d69d91d05eb0\",\r\n                    \"path\": \"<Gamepad>/leftStick/left\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"AimLeft\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"right\",\r\n                    \"id\": \"275a245a-3a2f-4bdb-89f5-7cdfe440480a\",\r\n                    \"path\": \"<Gamepad>/leftStick/right\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Gamepad\",\r\n                    \"action\": \"AimLeft\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                }\r\n            ]\r\n        },\r\n        {\r\n            \"name\": \"UI\",\r\n            \"id\": \"1bc44db1-9c18-40b8-af0b-baf330141850\",\r\n            \"actions\": [\r\n                {\r\n                    \"name\": \"MenuBack\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"3cab64fd-d828-48e1-aafa-718bf0b216fe\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"Press\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"TrackedDeviceOrientation\",\r\n                    \"type\": \"PassThrough\",\r\n                    \"id\": \"b8eb4c1b-1161-4ccc-99fb-61730219ba11\",\r\n                    \"expectedControlType\": \"Quaternion\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"TrackedDevicePosition\",\r\n                    \"type\": \"PassThrough\",\r\n                    \"id\": \"0dbf7f4d-a0a5-4855-a756-adadbd3783a0\",\r\n                    \"expectedControlType\": \"Vector3\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"RightClick\",\r\n                    \"type\": \"PassThrough\",\r\n                    \"id\": \"01ddc694-d795-4848-981f-a9011f07467d\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"MiddleClick\",\r\n                    \"type\": \"PassThrough\",\r\n                    \"id\": \"a96658f9-8533-4e26-86a2-fa1fdcd0b62a\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"ScrollWheel\",\r\n                    \"type\": \"PassThrough\",\r\n                    \"id\": \"102bd919-f45f-4a3c-85aa-df93ddfbae5b\",\r\n                    \"expectedControlType\": \"Vector2\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"Click\",\r\n                    \"type\": \"PassThrough\",\r\n                    \"id\": \"2dbf5c95-f3c2-4301-bdb9-b169f0e2f8ca\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"\",\r\n                    \"initialStateCheck\": true\r\n                },\r\n                {\r\n                    \"name\": \"Point\",\r\n                    \"type\": \"PassThrough\",\r\n                    \"id\": \"b71bdcd6-80cd-4eab-b957-ce5c03652418\",\r\n                    \"expectedControlType\": \"Vector2\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"\",\r\n                    \"initialStateCheck\": true\r\n                },\r\n                {\r\n                    \"name\": \"Cancel\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"f025b6d1-d88c-4524-a629-88e25e63aeba\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"Press\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"Submit\",\r\n                    \"type\": \"Button\",\r\n                    \"id\": \"41018a72-a82e-4da4-bffa-4b208c9bdd34\",\r\n                    \"expectedControlType\": \"Button\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"Press\",\r\n                    \"initialStateCheck\": false\r\n                },\r\n                {\r\n                    \"name\": \"Navigate\",\r\n                    \"type\": \"PassThrough\",\r\n                    \"id\": \"821022bc-d991-4583-bda5-1da6ec94fdee\",\r\n                    \"expectedControlType\": \"Vector2\",\r\n                    \"processors\": \"\",\r\n                    \"interactions\": \"\",\r\n                    \"initialStateCheck\": false\r\n                }\r\n            ],\r\n            \"bindings\": [\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"2611660b-a793-4bcf-8a06-dc4f4f844157\",\r\n                    \"path\": \"*/{Back}\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"MenuBack\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"WASD Keys\",\r\n                    \"id\": \"85205e05-164f-4d74-853b-eddcb2d0b00f\",\r\n                    \"path\": \"2DVector\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": true,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"Arrow Keys\",\r\n                    \"id\": \"6c314785-4c47-47bc-84ed-95197a8fb86f\",\r\n                    \"path\": \"2DVector\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": true,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"up\",\r\n                    \"id\": \"7c75bd1e-62d9-42d7-8a2b-3748bdb43dde\",\r\n                    \"path\": \"<Keyboard>/upArrow\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"down\",\r\n                    \"id\": \"32d0a327-8e85-4a19-a033-31dcccc97bd2\",\r\n                    \"path\": \"<Keyboard>/downArrow\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"left\",\r\n                    \"id\": \"350c2830-681b-4b93-b8e6-96ae1cbb838e\",\r\n                    \"path\": \"<Keyboard>/leftArrow\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"right\",\r\n                    \"id\": \"6a319b2c-7ff9-4c90-a624-fffa71dec252\",\r\n                    \"path\": \"<Keyboard>/rightArrow\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"up\",\r\n                    \"id\": \"35feb188-582f-411b-913b-d26b9e701337\",\r\n                    \"path\": \"<Keyboard>/w\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"up\",\r\n                    \"id\": \"69a7472e-6e28-4c63-b3e0-c6ce1d66c069\",\r\n                    \"path\": \"<Keyboard>/upArrow\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"down\",\r\n                    \"id\": \"6c6ce44c-0e16-43d1-9f86-d531429ad28a\",\r\n                    \"path\": \"<Keyboard>/s\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"down\",\r\n                    \"id\": \"cc4fc4e9-deb7-4efe-a29e-590bdbf3489b\",\r\n                    \"path\": \"<Keyboard>/downArrow\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"left\",\r\n                    \"id\": \"5fb151f8-b948-4cd4-9817-e3a1216b0f7d\",\r\n                    \"path\": \"<Keyboard>/a\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"left\",\r\n                    \"id\": \"2db911b2-d175-48c5-b5d6-0743e2a67d93\",\r\n                    \"path\": \"<Keyboard>/leftArrow\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"right\",\r\n                    \"id\": \"29bf19e0-210e-4f02-a6c7-c3303f840530\",\r\n                    \"path\": \"<Keyboard>/d\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"right\",\r\n                    \"id\": \"53ce8494-d4a6-404c-9f93-de31f91ca814\",\r\n                    \"path\": \"<Keyboard>/rightArrow\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": true\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"438c021c-064e-4291-811b-9dea70558949\",\r\n                    \"path\": \"<Gamepad>/dpad\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"32e5798e-0733-4e81-887d-645ac67e44f6\",\r\n                    \"path\": \"<Gamepad>/leftStick\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"StickDeadzone(min=0.5)\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"ec51276f-8d1e-4fd9-8c0c-fc8c472ec7c4\",\r\n                    \"path\": \"<Gamepad>/rightStick\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"StickDeadzone(min=0.5)\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Navigate\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"688902fc-e480-4e8b-ba4f-5fe8de10ac36\",\r\n                    \"path\": \"*/{Submit}\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Submit\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"c268fceb-477d-4730-9f7d-96e38ba3321c\",\r\n                    \"path\": \"<Keyboard>/space\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"Submit\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"dbb5de80-cc01-4c08-8b74-52e12ead14ad\",\r\n                    \"path\": \"<Gamepad>/start\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"Keyboard and Mouse\",\r\n                    \"action\": \"Submit\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"ea193b46-38b4-403b-8ada-52afd57369e3\",\r\n                    \"path\": \"*/{Cancel}\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Cancel\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"33ee87a5-9c44-42f3-846e-316ff8bb6abd\",\r\n                    \"path\": \"<Mouse>/position\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Point\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"6586669d-9474-4123-9125-94ac19b0780b\",\r\n                    \"path\": \"<Pen>/position\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Point\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"bf6fa32b-c0a5-483a-bdb8-98466ee281eb\",\r\n                    \"path\": \"<Touchscreen>/touch*/position\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Point\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"7b53b840-5ebb-4858-bfd8-c87877a3de08\",\r\n                    \"path\": \"<Mouse>/leftButton\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Click\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"a44f86da-08e2-4b63-8818-5b1ca778a2e7\",\r\n                    \"path\": \"<Pen>/tip\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Click\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"c9baca16-25d8-4c09-a8df-cbf041e12095\",\r\n                    \"path\": \"<Touchscreen>/touch*/press\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Click\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"fa85a7ce-d2d2-4ac4-888c-2066ec7c11dd\",\r\n                    \"path\": \"<XRController>/trigger\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"Click\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"c9215101-24c2-485e-bc5f-88a481beb7f5\",\r\n                    \"path\": \"<Mouse>/scroll\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"ScrollWheel\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"7db80d89-fd82-4c6d-ba56-97c248d6940f\",\r\n                    \"path\": \"<Mouse>/middleButton\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"MiddleClick\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"3a09c7cf-baac-455a-bc1f-2a2bfe930888\",\r\n                    \"path\": \"<Mouse>/rightButton\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"RightClick\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"a633fce4-beb8-400f-b007-076f36bc086f\",\r\n                    \"path\": \"<XRController>/devicePosition\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"TrackedDevicePosition\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                },\r\n                {\r\n                    \"name\": \"\",\r\n                    \"id\": \"ee209c71-23f7-4854-837f-21fa4277531e\",\r\n                    \"path\": \"<XRController>/deviceRotation\",\r\n                    \"interactions\": \"\",\r\n                    \"processors\": \"\",\r\n                    \"groups\": \"\",\r\n                    \"action\": \"TrackedDeviceOrientation\",\r\n                    \"isComposite\": false,\r\n                    \"isPartOfComposite\": false\r\n                }\r\n            ]\r\n        }\r\n    ],\r\n    \"controlSchemes\": [\r\n        {\r\n            \"name\": \"Keyboard and Mouse\",\r\n            \"bindingGroup\": \"Keyboard and Mouse\",\r\n            \"devices\": [\r\n                {\r\n                    \"devicePath\": \"<Keyboard>\",\r\n                    \"isOptional\": false,\r\n                    \"isOR\": false\r\n                },\r\n                {\r\n                    \"devicePath\": \"<Mouse>\",\r\n                    \"isOptional\": false,\r\n                    \"isOR\": false\r\n                }\r\n            ]\r\n        },\r\n        {\r\n            \"name\": \"Gamepad\",\r\n            \"bindingGroup\": \"Gamepad\",\r\n            \"devices\": [\r\n                {\r\n                    \"devicePath\": \"<Gamepad>\",\r\n                    \"isOptional\": false,\r\n                    \"isOR\": false\r\n                },\r\n                {\r\n                    \"devicePath\": \"<XInputController>\",\r\n                    \"isOptional\": true,\r\n                    \"isOR\": false\r\n                }\r\n            ]\r\n        }\r\n    ]\r\n}");
		m_Loading = asset.FindActionMap("Loading", throwIfNotFound: true);
		m_Loading_SkipIntro = m_Loading.FindAction("SkipIntro", throwIfNotFound: true);
		m_Loading_StartGame = m_Loading.FindAction("StartGame", throwIfNotFound: true);
		m_Loading_NextTip = m_Loading.FindAction("NextTip", throwIfNotFound: true);
		m_Gameplay = asset.FindActionMap("Gameplay", throwIfNotFound: true);
		m_Gameplay_MenuBack = m_Gameplay.FindAction("MenuBack", throwIfNotFound: true);
		m_Gameplay_MoveUp = m_Gameplay.FindAction("MoveUp", throwIfNotFound: true);
		m_Gameplay_MoveDown = m_Gameplay.FindAction("MoveDown", throwIfNotFound: true);
		m_Gameplay_MoveRight = m_Gameplay.FindAction("MoveRight", throwIfNotFound: true);
		m_Gameplay_MoveLeft = m_Gameplay.FindAction("MoveLeft", throwIfNotFound: true);
		m_Gameplay_Shoot = m_Gameplay.FindAction("Shoot", throwIfNotFound: true);
		m_Gameplay_Build = m_Gameplay.FindAction("Build", throwIfNotFound: true);
		m_Gameplay_OpenBuild = m_Gameplay.FindAction("OpenBuild", throwIfNotFound: true);
		m_Gameplay_Radar = m_Gameplay.FindAction("Radar", throwIfNotFound: true);
		m_Gameplay_Boost = m_Gameplay.FindAction("Boost", throwIfNotFound: true);
		m_Gameplay_AimRight = m_Gameplay.FindAction("AimRight", throwIfNotFound: true);
		m_Gameplay_AimLeft = m_Gameplay.FindAction("AimLeft", throwIfNotFound: true);
		m_UI = asset.FindActionMap("UI", throwIfNotFound: true);
		m_UI_MenuBack = m_UI.FindAction("MenuBack", throwIfNotFound: true);
		m_UI_TrackedDeviceOrientation = m_UI.FindAction("TrackedDeviceOrientation", throwIfNotFound: true);
		m_UI_TrackedDevicePosition = m_UI.FindAction("TrackedDevicePosition", throwIfNotFound: true);
		m_UI_RightClick = m_UI.FindAction("RightClick", throwIfNotFound: true);
		m_UI_MiddleClick = m_UI.FindAction("MiddleClick", throwIfNotFound: true);
		m_UI_ScrollWheel = m_UI.FindAction("ScrollWheel", throwIfNotFound: true);
		m_UI_Click = m_UI.FindAction("Click", throwIfNotFound: true);
		m_UI_Point = m_UI.FindAction("Point", throwIfNotFound: true);
		m_UI_Cancel = m_UI.FindAction("Cancel", throwIfNotFound: true);
		m_UI_Submit = m_UI.FindAction("Submit", throwIfNotFound: true);
		m_UI_Navigate = m_UI.FindAction("Navigate", throwIfNotFound: true);
	}

	public void Dispose()
	{
		UnityEngine.Object.Destroy(asset);
	}

	public bool Contains(InputAction action)
	{
		return asset.Contains(action);
	}

	public IEnumerator<InputAction> GetEnumerator()
	{
		return asset.GetEnumerator();
	}

	IEnumerator IEnumerable.GetEnumerator()
	{
		return GetEnumerator();
	}

	public void Enable()
	{
		asset.Enable();
	}

	public void Disable()
	{
		asset.Disable();
	}

	public InputAction FindAction(string actionNameOrId, bool throwIfNotFound = false)
	{
		return asset.FindAction(actionNameOrId, throwIfNotFound);
	}

	public int FindBinding(InputBinding bindingMask, out InputAction action)
	{
		return asset.FindBinding(bindingMask, out action);
	}
}
