using System.Collections;
using Steamworks;
using UnityEngine;

public class GoToURL : Singleton<GoToURL>
{
	protected Callback<GameOverlayActivated_t> m_GameOverlayActivated;

	private bool isOverLayActivated;

	private void OnEnable()
	{
		if (SteamManager.Initialized)
		{
			m_GameOverlayActivated = Callback<GameOverlayActivated_t>.Create(OnGameOverlayActivated);
		}
	}

	private void OnGameOverlayActivated(GameOverlayActivated_t pCallback)
	{
		isOverLayActivated = pCallback.m_bActive != 0;
	}

	public void GoToUrlUI(string URL)
	{
		StartCoroutine(OpenLinkCoroutine(URL));
	}

	public void GoToUrl(string URL)
	{
		StartCoroutine(OpenLinkCoroutine(URL));
	}

	private IEnumerator OpenLinkCoroutine(string URL)
	{
		if (SteamManager.Initialized && Singleton<GameBuildManager>.Instance.GetPlatform() == Platform.Steam)
		{
			SteamFriends.ActivateGameOverlayToWebPage(URL);
		}
		yield return new WaitForSeconds(1f);
		if (isOverLayActivated)
		{
			isOverLayActivated = false;
		}
		else if (Application.platform == RuntimePlatform.WebGLPlayer)
		{
			Application.ExternalEval("window.open(\"" + URL + " \",\"_blank\")");
		}
		else
		{
			Application.OpenURL(URL);
		}
	}
}
