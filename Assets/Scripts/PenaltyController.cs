using UnityEngine;
using System.Collections.Generic;

public class PenaltyController : MonoBehaviour
{
    public GameObject penaltySpherePrefab;         // Prefab to instantiate as penalty indicator
    public Vector3 penaltySize = new Vector3(1f, 1f, 0.1f);
    public int sphereCount = 100;

    public int basePenaltySeed = -1;               // Single base seed
    public int usedSeedPenalty { get; private set; }

    public List<Vector3> penaltyRandomValues = new List<Vector3>(); // First and last penalty positions

    private GameObject currentPenaltyGroup;        // Parent container for all penalty spheres
    private GameObject currentPenaltyObject;       // Bounding box (with collider) for penalty detection
    private List<Renderer> penaltyRenderers = new List<Renderer>();

    void Start()
    {
        if (basePenaltySeed < 0)
            basePenaltySeed = System.DateTime.Now.GetHashCode();
        Debug.Log($"[PenaltyController] BasePenaltySeed = {basePenaltySeed}");
    }

    /// <summary>
    /// Applies a penalty zone with deterministic random layout.
    /// </summary>
    public void ApplyPenalty(GameObject target, int trialIndex)
    {
        usedSeedPenalty = basePenaltySeed + trialIndex;
        Random.InitState(usedSeedPenalty);

        ClearPenalty();
        penaltyRenderers.Clear();
        penaltyRandomValues.Clear();

        Vector3[] directions = {
            Vector3.left, Vector3.right,
            Vector3.up, Vector3.down,
            Vector3.forward, Vector3.back
        };

        Vector3 dir = directions[Random.Range(0, directions.Length)];
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

        // Track first and last sphere positions
        Vector3 firstSphere = Vector3.zero;
        Vector3 lastSphere = Vector3.zero;

        // Generate penalty spheres
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
            sphere.transform.localScale = Vector3.one * 0.005f;

            Renderer sphereRenderer = sphere.GetComponent<Renderer>();
            if (sphereRenderer != null) penaltyRenderers.Add(sphereRenderer);
        }

        // Save only the first and last sphere positions
        penaltyRandomValues.Add(firstSphere);
        penaltyRandomValues.Add(lastSphere);

        Debug.Log($"[PenaltyController] PenaltySeed={usedSeedPenalty}, First={firstSphere}, Last={lastSphere}");
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
