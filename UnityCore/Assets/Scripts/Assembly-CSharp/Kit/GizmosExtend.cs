using System;
using System.Diagnostics;
using UnityEngine;

namespace Kit
{
	public static class GizmosExtend
	{
		private struct HandleColorScope : IDisposable
		{
			private Color oldColor;

			public HandleColorScope(Color color)
			{
				oldColor = Color.white;
			}

			public void Dispose()
			{
			}
		}

		public struct Box
		{
			public Vector3 localFrontTopLeft { get; private set; }

			public Vector3 localFrontTopRight { get; private set; }

			public Vector3 localFrontBottomLeft { get; private set; }

			public Vector3 localFrontBottomRight { get; private set; }

			public Vector3 localBackTopLeft => -localFrontBottomRight;

			public Vector3 localBackTopRight => -localFrontBottomLeft;

			public Vector3 localBackBottomLeft => -localFrontTopRight;

			public Vector3 localBackBottomRight => -localFrontTopLeft;

			public Vector3 frontTopLeft => localFrontTopLeft + origin;

			public Vector3 frontTopRight => localFrontTopRight + origin;

			public Vector3 frontBottomLeft => localFrontBottomLeft + origin;

			public Vector3 frontBottomRight => localFrontBottomRight + origin;

			public Vector3 backTopLeft => localBackTopLeft + origin;

			public Vector3 backTopRight => localBackTopRight + origin;

			public Vector3 backBottomLeft => localBackBottomLeft + origin;

			public Vector3 backBottomRight => localBackBottomRight + origin;

			public Vector3 origin { get; private set; }

			public Box(Vector3 origin, Vector3 halfExtents, Quaternion orientation)
				: this(origin, halfExtents)
			{
				Rotate(orientation);
			}

			public Box(Vector3 origin, Vector3 halfExtents)
			{
				this = default;
				localFrontTopLeft = new Vector3(0f - halfExtents.x, halfExtents.y, 0f - halfExtents.z);
				localFrontTopRight = new Vector3(halfExtents.x, halfExtents.y, 0f - halfExtents.z);
				localFrontBottomLeft = new Vector3(0f - halfExtents.x, 0f - halfExtents.y, 0f - halfExtents.z);
				localFrontBottomRight = new Vector3(halfExtents.x, 0f - halfExtents.y, 0f - halfExtents.z);
				this.origin = origin;
			}

			public void Rotate(Quaternion orientation)
			{
				localFrontTopLeft = RotatePointAroundPivot(localFrontTopLeft, Vector3.zero, orientation);
				localFrontTopRight = RotatePointAroundPivot(localFrontTopRight, Vector3.zero, orientation);
				localFrontBottomLeft = RotatePointAroundPivot(localFrontBottomLeft, Vector3.zero, orientation);
				localFrontBottomRight = RotatePointAroundPivot(localFrontBottomRight, Vector3.zero, orientation);
			}
		}

		private const bool IsHandleHackAvailable = false;

		public static void DrawPoint(Vector3 position, Color color = default(Color), float scale = 1f)
		{
			using (new ColorScope(color))
			{
				Gizmos.DrawRay(position + Vector3.up * (scale * 0.5f), -Vector3.up * scale);
				Gizmos.DrawRay(position + Vector3.right * (scale * 0.5f), -Vector3.right * scale);
				Gizmos.DrawRay(position + Vector3.forward * (scale * 0.5f), -Vector3.forward * scale);
			}
		}

		public static void DrawRay(Vector3 position, Vector3 direction, Color color = default(Color))
		{
			using (new ColorScope(color))
			{
				Gizmos.DrawRay(position, direction);
			}
		}

		public static void DrawLine(Vector3 from, Vector3 to, Color color = default(Color))
		{
			using (new ColorScope(color))
			{
				Gizmos.DrawLine(from, to);
			}
		}

		public static void DrawBounds(Bounds bounds, Color color = default(Color))
		{
			Vector3 vector = bounds.center + new Vector3(bounds.extents.x, bounds.extents.y, bounds.extents.z);
			Vector3 vector2 = bounds.center + new Vector3(bounds.extents.x, bounds.extents.y, 0f - bounds.extents.z);
			Vector3 vector3 = bounds.center + new Vector3(0f - bounds.extents.x, bounds.extents.y, bounds.extents.z);
			Vector3 vector4 = bounds.center + new Vector3(0f - bounds.extents.x, bounds.extents.y, 0f - bounds.extents.z);
			Vector3 vector5 = bounds.center + new Vector3(bounds.extents.x, 0f - bounds.extents.y, bounds.extents.z);
			Vector3 to = bounds.center + new Vector3(bounds.extents.x, 0f - bounds.extents.y, 0f - bounds.extents.z);
			Vector3 vector6 = bounds.center + new Vector3(0f - bounds.extents.x, 0f - bounds.extents.y, bounds.extents.z);
			Vector3 vector7 = bounds.center + new Vector3(0f - bounds.extents.x, 0f - bounds.extents.y, 0f - bounds.extents.z);
			using (new ColorScope(color))
			{
				Gizmos.DrawLine(vector, vector3);
				Gizmos.DrawLine(vector, vector2);
				Gizmos.DrawLine(vector3, vector4);
				Gizmos.DrawLine(vector2, vector4);
				Gizmos.DrawLine(vector, vector5);
				Gizmos.DrawLine(vector2, to);
				Gizmos.DrawLine(vector3, vector6);
				Gizmos.DrawLine(vector4, vector7);
				Gizmos.DrawLine(vector5, vector6);
				Gizmos.DrawLine(vector5, to);
				Gizmos.DrawLine(vector6, vector7);
				Gizmos.DrawLine(vector7, to);
			}
		}

		public static void DrawCircle(Vector3 position, Vector3 up = default(Vector3), Color color = default(Color), float radius = 1f)
		{
			up = ((up == default(Vector3)) ? Vector3.up : up).normalized * radius;
			Vector3 rhs = Vector3.Slerp(up, -up, 0.5f);
			Vector3 vector = Vector3.Cross(up, rhs).normalized * radius;
			Matrix4x4 matrix4x = new Matrix4x4
			{
				m00 = vector.x,
				m10 = vector.y,
				m20 = vector.z,
				m01 = up.x,
				m11 = up.y,
				m21 = up.z,
				m02 = rhs.x,
				m12 = rhs.y,
				m22 = rhs.z
			};
			Vector3 vector2 = position + matrix4x.MultiplyPoint3x4(new Vector3(Mathf.Cos(0f), 0f, Mathf.Sin(0f)));
			Vector3 zero = Vector3.zero;
			using (new ColorScope(color))
			{
				for (int i = 0; i <= 90; i++)
				{
					zero = position + matrix4x.MultiplyPoint3x4(new Vector3(Mathf.Cos((float)(i * 4) * ((float)Math.PI / 180f)), 0f, Mathf.Sin((float)(i * 4) * ((float)Math.PI / 180f))));
					Gizmos.DrawLine(vector2, zero);
					vector2 = zero;
				}
			}
		}

		public static void DrawCylinder(Vector3 start, Vector3 end, Color color = default(Color), float radius = 1f)
		{
			Vector3 vector = (end - start).normalized * radius;
			Vector3 vector2 = Vector3.Slerp(vector, -vector, 0.5f);
			Vector3 vector3 = Vector3.Cross(vector, vector2).normalized * radius;
			DrawCircle(start, vector, color, radius);
			DrawCircle(end, -vector, color, radius);
			DrawCircle((start + end) * 0.5f, vector, color, radius);
			using (new ColorScope(color))
			{
				Gizmos.DrawLine(start + vector3, end + vector3);
				Gizmos.DrawLine(start - vector3, end - vector3);
				Gizmos.DrawLine(start + vector2, end + vector2);
				Gizmos.DrawLine(start - vector2, end - vector2);
				Gizmos.DrawLine(start - vector3, start + vector3);
				Gizmos.DrawLine(start - vector2, start + vector2);
				Gizmos.DrawLine(end - vector3, end + vector3);
				Gizmos.DrawLine(end - vector2, end + vector2);
			}
		}

		public static void DrawCone(Vector3 position, Vector3 direction, Color color = default(Color), float angle = 45f)
		{
			float magnitude = direction.magnitude;
			angle = Mathf.Clamp(angle, 0f, 90f);
			Vector3 vector = direction;
			Vector3 vector2 = Vector3.Slerp(vector, -vector, 0.5f);
			Vector3 vector3 = Vector3.Cross(vector, vector2).normalized * magnitude;
			Vector3 direction2 = Vector3.Slerp(vector, vector2, angle / 90f);
			Plane plane = new Plane(-direction, position + vector);
			Ray ray = new Ray(position, direction2);
			plane.Raycast(ray, out var enter);
			using (new ColorScope(color))
			{
				Gizmos.DrawRay(position, direction2.normalized * enter);
				Gizmos.DrawRay(position, Vector3.Slerp(vector, -vector2, angle / 90f).normalized * enter);
				Gizmos.DrawRay(position, Vector3.Slerp(vector, vector3, angle / 90f).normalized * enter);
				Gizmos.DrawRay(position, Vector3.Slerp(vector, -vector3, angle / 90f).normalized * enter);
			}
			DrawCircle(position + vector, direction, color, (vector - direction2.normalized * enter).magnitude);
			DrawCircle(position + vector * 0.5f, direction, color, (vector * 0.5f - direction2.normalized * (enter * 0.5f)).magnitude);
		}

		public static void DrawArrow(Vector3 position, Vector3 direction, Color color = default(Color), float angle = 15f, float headLength = 0.3f)
		{
			if (direction == Vector3.zero)
			{
				return;
			}
			if (angle < 0f)
			{
				angle = Mathf.Abs(angle);
			}
			if (angle > 0f)
			{
				float num = direction.magnitude * Mathf.Clamp01(headLength);
				Vector3 direction2 = direction.normalized * (0f - num);
				DrawCone(position + direction, direction2, color, angle);
			}
			using (new ColorScope(color))
			{
				Gizmos.DrawRay(position, direction);
			}
		}

		public static void DrawCapsule(Vector3 point1, Vector3 point2, float radius = 1f, Color color = default(Color))
		{
			if (point1 == point2)
			{
				using (new ColorScope(color))
				{
					Gizmos.DrawWireSphere(point1, radius);
					return;
				}
			}
			float magnitude = (point1 - point2).magnitude;
			float num = Mathf.Max(0f, magnitude * 0.5f);
			Vector3 vector = (point2 - point1).normalized * radius;
			Vector3 vector2 = Vector3.Slerp(vector, -vector, 0.5f);
			Vector3 vector3 = Vector3.Cross(vector, vector2).normalized * radius;
			Vector3 vector4 = (point2 + point1) * 0.5f;
			point1 = vector4 + (point1 - vector4).normalized * num;
			point2 = vector4 + (point2 - vector4).normalized * num;
			DrawCircle(point1, vector, color, radius);
			DrawCircle(point2, -vector, color, radius);
			using (new ColorScope(color))
			{
				Gizmos.DrawLine(point1 + vector3, point2 + vector3);
				Gizmos.DrawLine(point1 - vector3, point2 - vector3);
				Gizmos.DrawLine(point1 + vector2, point2 + vector2);
				Gizmos.DrawLine(point1 - vector2, point2 - vector2);
				for (int i = 1; i < 26; i++)
				{
					Gizmos.DrawLine(Vector3.Slerp(vector3, -vector, (float)i / 25f) + point1, Vector3.Slerp(vector3, -vector, (float)(i - 1) / 25f) + point1);
					Gizmos.DrawLine(Vector3.Slerp(-vector3, -vector, (float)i / 25f) + point1, Vector3.Slerp(-vector3, -vector, (float)(i - 1) / 25f) + point1);
					Gizmos.DrawLine(Vector3.Slerp(vector2, -vector, (float)i / 25f) + point1, Vector3.Slerp(vector2, -vector, (float)(i - 1) / 25f) + point1);
					Gizmos.DrawLine(Vector3.Slerp(-vector2, -vector, (float)i / 25f) + point1, Vector3.Slerp(-vector2, -vector, (float)(i - 1) / 25f) + point1);
					Gizmos.DrawLine(Vector3.Slerp(vector3, vector, (float)i / 25f) + point2, Vector3.Slerp(vector3, vector, (float)(i - 1) / 25f) + point2);
					Gizmos.DrawLine(Vector3.Slerp(-vector3, vector, (float)i / 25f) + point2, Vector3.Slerp(-vector3, vector, (float)(i - 1) / 25f) + point2);
					Gizmos.DrawLine(Vector3.Slerp(vector2, vector, (float)i / 25f) + point2, Vector3.Slerp(vector2, vector, (float)(i - 1) / 25f) + point2);
					Gizmos.DrawLine(Vector3.Slerp(-vector2, vector, (float)i / 25f) + point2, Vector3.Slerp(-vector2, vector, (float)(i - 1) / 25f) + point2);
				}
			}
		}

		public static void DrawFrustum(Camera camera, Color color = default(Color))
		{
			using (new ColorScope(color))
			{
				Gizmos.matrix = Matrix4x4.TRS(camera.transform.position, camera.transform.rotation, Vector3.one);
				Gizmos.DrawFrustum(Vector3.zero, camera.fieldOfView, camera.farClipPlane, camera.nearClipPlane, camera.aspect);
				Gizmos.matrix = Matrix4x4.identity;
			}
		}

		public static void DrawPlane(Vector3 start, Vector3 end, Vector3 upward, float height = 1f, Color color = default(Color))
		{
			float num = Vector3.Distance(start, end);
			if (Mathf.Approximately(num, 0f))
			{
				return;
			}
			using (new ColorScope(color))
			{
				Quaternion q = Quaternion.LookRotation(end - start, upward) * Quaternion.Euler(0f, -90f, 0f);
				Gizmos.matrix = Matrix4x4.TRS(start, q, Vector3.one);
				Gizmos.DrawCube(new Vector3(num * 0.5f, height * 0.5f, 0f), new Vector3(num, height, float.Epsilon));
				Gizmos.matrix = Matrix4x4.identity;
			}
		}

		public static void DrawPlane(Transform self, float width, float height = 1f, Color color = default(Color))
		{
			DrawPlane(self.position, self.position + self.forward * width, self.up, height, color);
		}

		public static void DrawSphere(Transform self, Color color = default(Color))
		{
			DrawSphere(self.position, self.localScale.x, color);
		}

		public static void DrawSphere(Vector3 position, float radius, Color color = default(Color))
		{
			using (new ColorScope(color))
			{
				Gizmos.DrawSphere(position, radius);
			}
		}

		public static void DrawDirection(Transform self, Color color = default(Color))
		{
			DrawDirection(self.position, Vector3.forward, self.localScale.x, color);
		}

		public static void DrawDirection(Vector3 position, Vector3 direction, float distance = 1f, Color color = default(Color))
		{
			using (new ColorScope(color))
			{
				Gizmos.DrawLine(position, position + direction * distance);
			}
		}

		public static float GetHandleSize(Vector3 center)
		{
			return 1f;
		}

		[Conditional("UNITY_EDITOR")]
		public static void DrawLabel(Vector3 position, string text, GUIStyle style = null, Color color = default(Color), float offsetX = 0f, float offsetY = 0f)
		{
		}

		[Conditional("UNITY_EDITOR")]
		public static void DrawArc(Vector3 center, Vector3 normal, Vector3 from, float angle, float radius, Color color, bool constantScreenSize = true)
		{
		}

		[Conditional("UNITY_EDITOR")]
		public static void DrawAngleBetween(Vector3 center, Vector3 from, Vector3 to, Vector3 axis, float radius, Color color, bool constantScreenSize = true, bool label = false)
		{
		}

		public static void DrawBox(Vector3 origin, Vector3 halfExtents, Quaternion orientation, Color color = default(Color))
		{
			DrawBox(new Box(origin, halfExtents, orientation), color);
		}

		public static void DrawBox(Box box, Color color = default(Color))
		{
			using (new ColorScope(color))
			{
				Gizmos.DrawLine(box.frontTopLeft, box.frontTopRight);
				Gizmos.DrawLine(box.frontTopRight, box.frontBottomRight);
				Gizmos.DrawLine(box.frontBottomRight, box.frontBottomLeft);
				Gizmos.DrawLine(box.frontBottomLeft, box.frontTopLeft);
				Gizmos.DrawLine(box.backTopLeft, box.backTopRight);
				Gizmos.DrawLine(box.backTopRight, box.backBottomRight);
				Gizmos.DrawLine(box.backBottomRight, box.backBottomLeft);
				Gizmos.DrawLine(box.backBottomLeft, box.backTopLeft);
				Gizmos.DrawLine(box.frontTopLeft, box.backTopLeft);
				Gizmos.DrawLine(box.frontTopRight, box.backTopRight);
				Gizmos.DrawLine(box.frontBottomRight, box.backBottomRight);
				Gizmos.DrawLine(box.frontBottomLeft, box.backBottomLeft);
			}
		}

		public static void DrawBoxCastOnHit(Vector3 origin, Vector3 halfExtents, Quaternion orientation, Vector3 direction, float hitInfoDistance, Color color = default(Color))
		{
			origin = CastCenterOnCollision(origin, direction, hitInfoDistance);
			DrawBox(origin, halfExtents, orientation, color);
		}

		public static void DrawBoxCastBox(Vector3 origin, Vector3 halfExtents, Quaternion orientation, Vector3 direction, float distance, Color color = default(Color))
		{
			direction.Normalize();
			Box box = new Box(origin, halfExtents, orientation);
			Box box2 = new Box(origin + direction * distance, halfExtents, orientation);
			using (new ColorScope(color))
			{
				Gizmos.DrawLine(box.backBottomLeft, box2.backBottomLeft);
				Gizmos.DrawLine(box.backBottomRight, box2.backBottomRight);
				Gizmos.DrawLine(box.backTopLeft, box2.backTopLeft);
				Gizmos.DrawLine(box.backTopRight, box2.backTopRight);
				Gizmos.DrawLine(box.frontTopLeft, box2.frontTopLeft);
				Gizmos.DrawLine(box.frontTopRight, box2.frontTopRight);
				Gizmos.DrawLine(box.frontBottomLeft, box2.frontBottomLeft);
				Gizmos.DrawLine(box.frontBottomRight, box2.frontBottomRight);
			}
			DrawBox(box, color);
			DrawBox(box2, color);
		}

		private static Vector3 CastCenterOnCollision(Vector3 origin, Vector3 direction, float hitInfoDistance)
		{
			return origin + direction.normalized * hitInfoDistance;
		}

		private static Vector3 RotatePointAroundPivot(Vector3 point, Vector3 pivot, Quaternion rotation)
		{
			Vector3 vector = point - pivot;
			return pivot + rotation * vector;
		}

		[Obsolete("Use DrawBox", true)]
		private static void DrawLocalCube(ref Color color, ref Vector3 lbb, ref Vector3 rbb, ref Vector3 lbf, ref Vector3 rbf, ref Vector3 lub, ref Vector3 rub, ref Vector3 luf, ref Vector3 ruf)
		{
			using (new ColorScope(color))
			{
				Gizmos.DrawLine(lbb, rbb);
				Gizmos.DrawLine(rbb, lbf);
				Gizmos.DrawLine(lbf, rbf);
				Gizmos.DrawLine(rbf, lbb);
				Gizmos.DrawLine(lub, rub);
				Gizmos.DrawLine(rub, luf);
				Gizmos.DrawLine(luf, ruf);
				Gizmos.DrawLine(ruf, lub);
				Gizmos.DrawLine(lbb, lub);
				Gizmos.DrawLine(rbb, rub);
				Gizmos.DrawLine(lbf, luf);
				Gizmos.DrawLine(rbf, ruf);
			}
		}

		[Obsolete("Use DrawBox", true)]
		public static void DrawLocalCube(Transform transform, Vector3 size, Color color = default(Color), Vector3 center = default(Vector3))
		{
			DrawBox(new Box(transform.position, size * 0.5f, transform.rotation), color);
		}

		[Obsolete("Use DrawBox", true)]
		public static void DrawLocalCube(Matrix4x4 space, Vector3 size = default(Vector3), Color color = default(Color), Vector3 center = default(Vector3))
		{
			size = ((size == default(Vector3)) ? Vector3.one : size);
			Vector3 lbb = space.MultiplyPoint3x4(center + -size * 0.5f);
			Vector3 rbb = space.MultiplyPoint3x4(center + new Vector3(size.x, 0f - size.y, 0f - size.z) * 0.5f);
			Vector3 lbf = space.MultiplyPoint3x4(center + new Vector3(size.x, 0f - size.y, size.z) * 0.5f);
			Vector3 rbf = space.MultiplyPoint3x4(center + new Vector3(0f - size.x, 0f - size.y, size.z) * 0.5f);
			Vector3 lub = space.MultiplyPoint3x4(center + new Vector3(0f - size.x, size.y, 0f - size.z) * 0.5f);
			Vector3 rub = space.MultiplyPoint3x4(center + new Vector3(size.x, size.y, 0f - size.z) * 0.5f);
			Vector3 luf = space.MultiplyPoint3x4(center + size * 0.5f);
			Vector3 ruf = space.MultiplyPoint3x4(center + new Vector3(0f - size.x, size.y, size.z) * 0.5f);
			DrawLocalCube(ref color, ref lbb, ref rbb, ref lbf, ref rbf, ref lub, ref rub, ref luf, ref ruf);
		}

		[Obsolete("Use DrawBox", true)]
		public static void DrawLocalCube(Vector3 position, Quaternion rotation, Vector3 size = default(Vector3), Color color = default(Color))
		{
			DrawLocalCube(Matrix4x4.TRS(position, rotation, Vector3.one), size, color, Vector3.zero);
		}
	}
}
