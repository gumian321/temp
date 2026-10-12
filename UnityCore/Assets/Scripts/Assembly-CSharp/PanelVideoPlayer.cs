using UnityEngine;
using UnityEngine.Video;

public class PanelVideoPlayer : MonoBehaviour
{
	[SerializeField]
	private VideoPlayer videoPlayer;

	public void SetVideo(VideoClip videoClip)
	{
		videoPlayer.clip = videoClip;
		PlayVideo();
	}

	public void PlayVideo()
	{
		if (videoPlayer.gameObject.activeInHierarchy)
		{
			videoPlayer.Play();
		}
	}

	public void StopVideo()
	{
		if (videoPlayer.gameObject.activeInHierarchy)
		{
			videoPlayer.Stop();
		}
	}
}
