using Steamworks;
using UnityEngine;

public class SteamUtilsManager : MonoBehaviour
{
	public static Texture2D GetSteamAvatar(CSteamID id)
	{
		return GetSteamImageAsTexture2D(SteamFriends.GetLargeFriendAvatar(id));
	}

	private static Texture2D GetSteamImageAsTexture2D(int iImage)
	{
		Texture2D texture2D = null;
		if (SteamUtils.GetImageSize(iImage, out var pnWidth, out var pnHeight))
		{
			byte[] array = new byte[pnWidth * pnHeight * 4];
			if (SteamUtils.GetImageRGBA(iImage, array, (int)(pnWidth * pnHeight * 4)))
			{
				texture2D = new Texture2D((int)pnWidth, (int)pnHeight, TextureFormat.RGBA32, mipChain: false, linear: true);
				texture2D.LoadRawTextureData(array);
				texture2D.Apply();
			}
		}
		return texture2D;
	}
}
