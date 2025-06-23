using UnityEngine;

public class PenaltyController : MonoBehaviour
{
    public GameObject penaltySpherePrefab;  // instead of a cube
    public Vector3 penaltySize = new Vector3(1f, 1f, 0.1f);
    public int sphereCount = 100;

    private GameObject currentPenalty;

    public void ApplyPenalty(GameObject target)
    {
        ClearPenalty();

        // Create parent object
        currentPenalty = new GameObject("PenaltyZone");
        currentPenalty.transform.parent = transform;

        Vector3[] directions = {
            Vector3.left, Vector3.right,
            Vector3.up, Vector3.down,
            Vector3.forward, Vector3.back
        };

        Vector3 dir = directions[Random.Range(0, directions.Length)];

        Vector3 offset = Vector3.Scale(dir, penaltySize) * 0.5f;
        Vector3 center = target.transform.position + offset;

        // Generate small spheres inside a box shape
        for (int i = 0; i < sphereCount; i++)
        {
            Vector3 randomOffset = new Vector3(
                Random.Range(-penaltySize.x / 2, penaltySize.x / 2),
                Random.Range(-penaltySize.y / 2, penaltySize.y / 2),
                Random.Range(-penaltySize.z / 2, penaltySize.z / 2)
            );

            GameObject sphere = Instantiate(penaltySpherePrefab, center + randomOffset, Quaternion.identity, currentPenalty.transform);
            sphere.transform.localScale = Vector3.one * 0.03f;
        }

        // Store bounds for hit detection
        GameManager.Instance.PenaltyPos = new Bounds(center, penaltySize);
    }

    public void ClearPenalty()
    {
        if (currentPenalty != null)
            Destroy(currentPenalty);
    }
}
