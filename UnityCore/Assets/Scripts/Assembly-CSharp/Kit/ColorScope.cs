using System;
using UnityEngine;

namespace Kit
{
	public struct ColorScope : IDisposable
	{
		private Color oldColor;

		public ColorScope(Color color)
		{
			oldColor = Gizmos.color;
			Gizmos.color = ((color == default(Color)) ? oldColor : color);
		}

		public void Dispose()
		{
			Gizmos.color = oldColor;
		}
	}
}
