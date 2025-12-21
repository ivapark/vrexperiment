using System.Collections.Generic;
using UnityEngine;

public class TargetController : MonoBehaviour
{
    public GameObject blueBallPrefab;          // unused now, safe to remove later if you want
    public GameObject visualSpherePrefab;
    public Material targetPrepMaterial;

    public Transform targetParent;
    public Transform startCircleTransform; // assign in Inspector
    public float spacing = 0.1f;           // XY spread between grid points
    public float targetDistance = 0.2f;    // distance from start circle to each target

    public float targetGroupScale = 1f;    // 1 = current size, <1 smaller, >1 bigger

    // Single radius knob: controls dot spread
    public float targetRadius = 0.02f;

    public float dotScale = 0.01f;

    public int usedSeed { get; private set; }
    public List<Vector3> targetRandomValues = new List<Vector3>();
    public List<GameObject> targets = new List<GameObject>();

    void Start()
    {
        Debug.Log("TargetController Start called");
        GenerateTargets();
    }

    /// <summary>
    /// Generate a 3x3 curved grid of targets.
    /// </summary>
    void GenerateTargets()
    {
        if (startCircleTransform == null)
        {
            Debug.LogError("StartCircleTransform not assigned in inspector!");
            return;
        }

        Vector3 origin = startCircleTransform.position;
        targets.Clear();

        for (int y = -1; y <= 1; y++)
        {
            for (int x = -1; x <= 1; x++)
            {
                float xOffset = x * spacing;
                float yOffset = y * spacing;

                float xSq = xOffset * xOffset;
                float ySq = yOffset * yOffset;
                float totalSq = targetDistance * targetDistance;

                // Prevent invalid sqrt
                if (xSq + ySq >= totalSq)
                {
                    Debug.LogWarning($"Target ({x},{y}) is too far in XY plane. Skipping.");
                    continue;
                }

                float zOffset = Mathf.Sqrt(totalSq - xSq - ySq);
                Vector3 offset = new Vector3(xOffset, yOffset, zOffset);
                Vector3 pos = origin + offset;

                GameObject targetGroup = new GameObject("Target_" + targets.Count);
                targetGroup.transform.SetParent(targetParent);
                targetGroup.transform.position = pos;
                targetGroup.transform.localScale = Vector3.one * targetGroupScale;

                targetGroup.SetActive(false);

                // No core, no collider – just dots
                CreateDots(targetGroup, pos);
                targets.Add(targetGroup);

                Debug.Log($"Target {targets.Count - 1} at {pos} (x={xOffset}, y={yOffset}, z={zOffset})");
            }
        }
    }

    void CreateDots(GameObject targetGroup, Vector3 pos)
    {
        targetRandomValues.Clear();
        Vector3 firstDot = Vector3.zero;
        Vector3 lastDot = Vector3.zero;

        for (int i = 0; i < 250; i++)
        {
            Vector3 offset = Random.insideUnitSphere * targetRadius;
            Vector3 dotPosition = pos + offset;

            if (i == 0) firstDot = dotPosition;
            if (i == 249) lastDot = dotPosition;

            GameObject visual = Instantiate(visualSpherePrefab, dotPosition, Quaternion.identity, targetGroup.transform);
            visual.transform.localScale = Vector3.one * dotScale;
            visual.name = "Dot_" + i;

            Renderer rend = visual.GetComponentInChildren<Renderer>();
            if (rend != null)
                rend.material = targetPrepMaterial;
            else
                Debug.LogWarning("Renderer not found on: " + visual.name);
        }

        targetRandomValues.Add(firstDot);
        targetRandomValues.Add(lastDot);

        Debug.Log($"[TargetController] First Dot: {firstDot}, Last Dot: {lastDot}");
    }

    public void GenerateDotsForTarget(int index)
    {
        if (index < 0 || index >= targets.Count)
        {
            Debug.LogWarning("Invalid target index for regeneration.");
            return;
        }

        GameObject targetGroup = targets[index];
        List<Transform> toDestroy = new List<Transform>();

        foreach (Transform child in targetGroup.transform)
        {
            if (child.name.StartsWith("Dot_"))
                toDestroy.Add(child);
        }
        foreach (Transform child in toDestroy)
            Destroy(child.gameObject);

        CreateDots(targetGroup, targetGroup.transform.position);
    }

    public void ActivateOnly(int index)
    {
        Debug.Log($"[ActivateOnly] Called with index: {index}");

        if (targets == null || targets.Count == 0)
        {
            Debug.LogWarning("Target list is empty!");
            return;
        }

        if (index < 0 || index >= targets.Count)
        {
            Debug.LogWarning($"[ActivateOnly] Index out of bounds: {index}, targets.Count = {targets.Count}");
            return;
        }

        for (int i = 0; i < targets.Count; i++)
        {
            bool shouldBeActive = (i == index);
            targets[i].SetActive(shouldBeActive);
            if (shouldBeActive)
                Debug.Log($"Target {i} ACTIVATED at position: {targets[i].transform.position}");
        }
    }

    public GameObject GetTarget(int index)
    {
        return (index >= 0 && index < targets.Count) ? targets[index] : null;
    }

    public void DeactivateAll()
    {
        foreach (GameObject target in targets)
            target.SetActive(false);
    }

    public void SetMaterial(Material mat)
    {
        foreach (GameObject group in targets)
        {
            if (!group.activeSelf) continue;

            foreach (Transform child in group.transform)
            {
                if (child.name.StartsWith("Dot_"))
                {
                    Renderer rend = child.GetComponentInChildren<Renderer>();
                    if (rend != null)
                        rend.material = mat;
                }
            }
        }
    }

    public void SetFeedbackMaterial(string outcome, Material hit, Material miss, Material neutral, Material tooSlow)
    {
        Material mat = outcome switch
        {
            "Hit Target" => hit,
            "Hit Penalty" or "Hit Both" => miss,
            "Missed" => neutral,
            _ => tooSlow
        };

        SetMaterial(mat);
        Debug.Log("SetMaterial called for Target, applying: " + mat.name);
    }
}
