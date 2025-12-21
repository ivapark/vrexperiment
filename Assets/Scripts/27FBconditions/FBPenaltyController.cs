using UnityEngine;
using System.Collections.Generic;

public class FBPenaltyController : MonoBehaviour
{
    public GameObject penaltySpherePrefab;
    public Vector3 penaltySize = new Vector3(1f, 1f, 0.1f);
    public int sphereCount = 100;

    public int basePenaltySeed = -1;
    public int usedSeedPenalty { get; private set; }

    public List<Vector3> penaltyRandomValues = new List<Vector3>();

    private GameObject currentPenaltyGroup;
    private GameObject currentPenaltyObject;
    private List<Renderer> penaltyRenderers = new List<Renderer>();

    void Start()
    {
        if (basePenaltySeed < 0)
            basePenaltySeed = System.DateTime.Now.GetHashCode();
        Debug.Log($"[FBPenaltyController] BasePenaltySeed = {basePenaltySeed}");
    }

    /// <summary>
    /// Applies a front or back penalty zone. 0 = none, 1 = front, 2 = back.
    /// </summary>
    public void ApplyPenalty(GameObject target, int penaltyIndex)
    {
        if (penaltyIndex == 0)
        {
            Debug.Log("[FBPenaltyController] No penalty applied for this trial.");
            ClearPenalty();
            usedSeedPenalty = -1;
            penaltyRandomValues.Clear();
            return;
        }

        usedSeedPenalty = basePenaltySeed + penaltyIndex;
        Random.InitState(usedSeedPenalty);

        ClearPenalty();
        penaltyRenderers.Clear();
        penaltyRandomValues.Clear();

        // 1 = front (forward +Z), 2 = back (backward -Z)
        Vector3 dir = penaltyIndex switch
        {
            1 => Vector3.forward,
            2 => Vector3.back,
            _ => Vector3.zero
        };

        Vector3 offset = Vector3.Scale(dir, penaltySize) * 0.5f;
        Vector3 center = target.transform.position + offset;

        currentPenaltyGroup = new GameObject("PenaltyZoneGroup");
        currentPenaltyGroup.transform.parent = transform;

        currentPenaltyObject = GameObject.CreatePrimitive(PrimitiveType.Cube);
        currentPenaltyObject.name = "PenaltyBounds";
        currentPenaltyObject.transform.position = center;
        currentPenaltyObject.transform.localScale = penaltySize;
        currentPenaltyObject.transform.parent = currentPenaltyGroup.transform;

        Collider cubeCol = currentPenaltyObject.GetComponent<Collider>();
        if (cubeCol != null) cubeCol.isTrigger = true;

        Renderer cubeRenderer = currentPenaltyObject.GetComponent<Renderer>();
        if (cubeRenderer != null) cubeRenderer.enabled = false;

        Vector3 firstSphere = Vector3.zero;
        Vector3 lastSphere = Vector3.zero;

        for (int i = 0; i < sphereCount; i++)
        {
            Vector3 randomOffset = new Vector3(
                Random.Range(-penaltySize.x / 2, penaltySize.x / 2),
                Random.Range(-penaltySize.y / 2, penaltySize.y / 2),
                Random.Range(-penaltySize.z / 2, penaltySize.z / 2)
            );

            Vector3 spherePosition = center + randomOffset;
            if (i == 0) firstSphere = spherePosition;
            if (i == sphereCount - 1) lastSphere = spherePosition;

            GameObject sphere = Instantiate(penaltySpherePrefab, spherePosition, Quaternion.identity, currentPenaltyGroup.transform);
            sphere.transform.localScale = Vector3.one * 0.03f;

            Renderer sphereRenderer = sphere.GetComponent<Renderer>();
            if (sphereRenderer != null) penaltyRenderers.Add(sphereRenderer);
        }

        penaltyRandomValues.Add(firstSphere);
        penaltyRandomValues.Add(lastSphere);

        Debug.Log($"[FBPenaltyController] PenaltySeed={usedSeedPenalty}, First={firstSphere}, Last={lastSphere}");
    }

    public void ClearPenalty()
    {
        if (currentPenaltyGroup != null)
            Destroy(currentPenaltyGroup);

        currentPenaltyGroup = null;
        currentPenaltyObject = null;
        penaltyRenderers.Clear();
    }

    public Bounds GetActivePenaltyBounds()
    {
        return currentPenaltyObject != null
            ? currentPenaltyObject.GetComponent<Collider>().bounds
            : new Bounds(Vector3.zero, Vector3.zero);
    }

    public Vector3 GetActivePenaltyCenter()
    {
        return currentPenaltyObject != null
            ? currentPenaltyObject.transform.position
            : Vector3.zero;
    }

    public void SetColor(Color color)
    {
        foreach (Renderer rend in penaltyRenderers)
        {
            if (rend != null)
                rend.material.color = color;
        }
    }

    public void SetMaterial(Material mat)
    {
        if (currentPenaltyGroup == null) return;

        Renderer[] renderers = currentPenaltyGroup.GetComponentsInChildren<Renderer>();
        foreach (Renderer rend in renderers)
        {
            if (rend != null)
                rend.material = mat;
        }
    }

    public void SetFeedbackMaterial(string outcome, Material hit, Material miss, Material neutral, Material tooSlow)
    {
        if (currentPenaltyGroup == null) return;

        Material mat = outcome switch
        {
            "Hit" => hit,
            "Missed" or "Hit Both" => miss,
            "Neutral" => neutral,
            _ => tooSlow
        };
        SetMaterial(mat);
    }
}
