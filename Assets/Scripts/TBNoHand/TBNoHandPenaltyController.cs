using UnityEngine;
using System.Collections.Generic;

public class TBNoHandPenaltyController : MonoBehaviour
{
    public GameObject penaltySpherePrefab;         // Prefab to instantiate as penalty indicator

    // Logical size of the penalty box (used for collider & random positions)
    public Vector3 penaltySize = new Vector3(1f, 1f, 0.1f);

    // How many small spheres to spawn as visual penalty dots
    public int sphereCount = 250;                  // more spheres by default

    // Visual scale of each small penalty sphere
    public float penaltySphereScale = 0.003f;      // smaller circles

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
        Debug.Log($"[TBPenaltyController] BasePenaltySeed = {basePenaltySeed}");
    }

    /// <summary>
    /// Applies a top/bottom penalty zone based on penaltyIndex.
    /// If penaltyIndex == 0, no penalty is applied.
    /// Mapping: 1 = top (+Y), 2 = bottom (-Y)
    /// </summary>
    public void ApplyPenalty(GameObject target, int penaltyIndex)
    {
        // If penaltyIndex is 0 (no penalty), skip generation
        if (penaltyIndex == 0)
        {
            Debug.Log("[TBPenaltyController] No penalty applied for this trial.");
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

        // Directions: 1=top, 2=bottom
        Vector3 dir = penaltyIndex switch
        {
            1 => Vector3.up,
            2 => Vector3.down,
            _ => Vector3.up // fallback
        };

        Vector3 offset = Vector3.Scale(dir, penaltySize) * 0.5f;
        Vector3 center = target.transform.position + offset;

        currentPenaltyGroup = new GameObject("PenaltyZoneGroup");
        currentPenaltyGroup.transform.parent = transform;

        // Invisible cube that defines the bounds used for hit detection
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

        // Generate penalty spheres (visual dots)
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

            GameObject sphere = Instantiate(
                penaltySpherePrefab,
                spherePosition,
                Quaternion.identity,
                currentPenaltyGroup.transform
            );

            // smaller visible circles
            sphere.transform.localScale = Vector3.one * penaltySphereScale;

            Renderer sphereRenderer = sphere.GetComponent<Renderer>();
            if (sphereRenderer != null) penaltyRenderers.Add(sphereRenderer);
        }

        // Store first and last sphere positions for logging
        penaltyRandomValues.Add(firstSphere);
        penaltyRandomValues.Add(lastSphere);

        Debug.Log($"[TBPenaltyController] PenaltySeed={usedSeedPenalty}, First={firstSphere}, Last={lastSphere}");
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

        // Match LR controller outcome mapping
        Material mat = outcome switch
        {
            "Hit Target" => hit,
            "Hit Penalty" or "Hit Both" => miss,
            "Missed" => neutral,
            _ => tooSlow
        };

        SetMaterial(mat);
    }
}
