using System.Collections.Generic;
using UnityEngine;

public class TargetOnlyTargetController : MonoBehaviour
{
    public GameObject blueBallPrefab;
    public GameObject visualSpherePrefab;
    public Material targetPrepMaterial;

    public Transform targetParent;
    public Transform startCircleTransform;  // assign in Inspector
    public float spacing = 0.1f;            // control XY spread
    public float targetDistance = 0.2f;     // fixed distance from start circle    public Material targetPrepMaterial;

    public int usedSeed { get; private set; } // For logging
    public List<Vector3> targetRandomValues = new List<Vector3>(); // Store first & last random values

    public List<GameObject> targets = new List<GameObject>();

    void Start()
    {
        Debug.Log("TargetController Start called");
        GenerateTargets();
    }

    /// <summary>
    /// Generate initial target groups (3x3 grid).
    /// </summary>

    void GenerateTargets()
    {
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

                // Ensure it's within valid range to avoid sqrt of negative
                if (xSq + ySq >= totalSq)
                {
                    Debug.LogWarning($"Target ({x},{y}) is too far in XY plane to fit in 0.3m radius. Skipping.");
                    continue;
                }

                float zOffset = Mathf.Sqrt(totalSq - xSq - ySq);
                Vector3 offset = new Vector3(xOffset, yOffset, zOffset);
                Vector3 pos = origin + offset;

                GameObject targetGroup = new GameObject("Target_" + targets.Count);
                targetGroup.transform.SetParent(targetParent);
                targetGroup.transform.position = pos;
                targetGroup.SetActive(false);

                GameObject targetCore = Instantiate(blueBallPrefab, pos, Quaternion.identity, targetGroup.transform);
                targetCore.name = "Core";

                Renderer coreRenderer = targetCore.GetComponent<Renderer>();
                if (coreRenderer != null) coreRenderer.enabled = false;

                Collider coreCollider = targetCore.GetComponent<Collider>();
                if (coreCollider != null) coreCollider.isTrigger = true;

                CreateDots(targetGroup, pos);
                targets.Add(targetGroup);

                Debug.Log($"Target {targets.Count - 1} at {pos} (x={xOffset}, y={yOffset}, z={zOffset})");
            }
        }
    }


    /// <summary>
    /// Generate dots around a target position and track first/last dot positions.
    /// </summary>
    void CreateDots(GameObject targetGroup, Vector3 pos)
    {
        targetRandomValues.Clear(); // Reset for this run
        Vector3 firstDot = Vector3.zero;
        Vector3 lastDot = Vector3.zero;

        for (int i = 0; i < 250; i++)
        {
            Vector3 offset = Random.insideUnitSphere * 0.03f; //radius 3cm
            Vector3 dotPosition = pos + offset;

            if (i == 0) firstDot = dotPosition;
            if (i == 249) lastDot = dotPosition;

            GameObject visual = Instantiate(visualSpherePrefab, dotPosition, Quaternion.identity, targetGroup.transform);
            visual.transform.localScale = Vector3.one * 0.015f;
            visual.name = "Dot_" + i;

            Renderer rend = visual.GetComponentInChildren<Renderer>();
            if (rend != null)
                rend.material = targetPrepMaterial;
            else
                Debug.LogWarning("Renderer not found on: " + visual.name);
        }

        // Save only the first and last dot positions
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
            bool shouldBeActive = i == index;
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
            "Hit" => hit,
            "Missed" or "Hit Both" => miss,
            "Neutral" => neutral,
            _ => tooSlow
        };

        SetMaterial(mat);
        Debug.Log("SetMaterial called for Target, applying: " + mat.name);
    }
}
