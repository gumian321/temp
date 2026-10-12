using UnityEngine;

public class ObjectSystem : MonoBehaviour
{
	public static void ReScaleX(Transform obj, float scale)
	{
		Vector3 localScale = obj.transform.localScale;
		localScale.x = scale;
		obj.transform.localScale = localScale;
	}

	public static void ReScale(GameObject obj, float scale)
	{
		obj.transform.localScale = Vector3.one * scale;
	}

	public static void ReScale(Transform obj, float scale)
	{
		obj.localScale = Vector3.one * scale;
	}

	public static void SetOnRandomEdgePos(Transform obj, Transform center, float spawningRadius, float delta = 5f)
	{
		spawningRadius = Random.Range(spawningRadius - delta, spawningRadius + delta);
		obj.transform.position = center.position + (Vector3)(Random.insideUnitCircle.normalized * spawningRadius);
	}

	public static void SetBetweenTwoPoints(Transform obj, Vector3 A, Vector3 B, float x)
	{
		obj.transform.position = Vector2.Lerp(A, B, x);
	}

	public static Vector3 GetRandomEdgePos(Transform center, float spawningRadius, float delta = 5f)
	{
		spawningRadius = Random.Range(spawningRadius - delta, spawningRadius + delta);
		return center.position + (Vector3)(Random.insideUnitCircle.normalized * spawningRadius);
	}

	public static Vector3 GetRandomPosInCircle(Vector2 center, float radius)
	{
		return center + Random.insideUnitCircle * radius;
	}

	public static void RotateAt(Transform obj, Transform lookAt)
	{
		RotateAt(obj, lookAt.position);
	}

	public static void RotateAt(Transform obj, Vector3 lookAt)
	{
		Vector3 vector = obj.position - lookAt;
		float num = Mathf.Atan2(vector.y, vector.x) * 57.29578f;
		num += 180f;
		obj.transform.rotation = Quaternion.AngleAxis(num, Vector3.forward);
	}

	public static void RotateToTarget(Transform obj, Vector2 targetPosition, float speed = 100f)
	{
		float num = Mathf.Atan2(targetPosition.y - obj.position.y, targetPosition.x - obj.position.x) * 57.29578f;
		num -= 90f;
		Quaternion to = Quaternion.Euler(new Vector3(0f, 0f, num));
		obj.rotation = Quaternion.RotateTowards(obj.rotation, to, speed * Time.deltaTime);
	}

	public static void SnapRotateToTarget(Transform obj, Vector2 targetPosition)
	{
		float num = Mathf.Atan2(targetPosition.y - obj.position.y, targetPosition.x - obj.position.x) * 57.29578f;
		num -= 90f;
		Quaternion rotation = Quaternion.Euler(new Vector3(0f, 0f, num));
		obj.rotation = rotation;
	}
}
