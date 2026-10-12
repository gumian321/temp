using UnityEngine;

public class Engine : MonoBehaviour
{
	[SerializeField]
	private ParticleSystem engineParticle;

	private ParticleSystem.MainModule mainModule;

	[SerializeField]
	private float startSize;

	[SerializeField]
	private float boostSize;

	private void Start()
	{
		startSize = PlayerDataStore.GetStartEngineSize();
		boostSize = PlayerDataStore.GetBoostEngineSize();
	}

	public void SetEngineBoostState(bool state)
	{
		if (!(base.transform == null))
		{
			TweenController.KillTweens(base.transform);
			if (state)
			{
				TweenController.DOFloat(startSize, boostSize, TweenDuration.Super_Short, ChangeEngineSize);
			}
			else
			{
				TweenController.DOFloat(boostSize, startSize, TweenDuration.Super_Short, ChangeEngineSize);
			}
		}
	}

	private void ChangeEngineSize(float size)
	{
		ParticleSystem.MainModule main = engineParticle.main;
		main.startSize = size;
	}

	public void SetEngineState(bool state)
	{
		if (state)
		{
			engineParticle.Play(withChildren: true);
		}
		else
		{
			engineParticle.Stop(withChildren: true);
		}
	}
}
