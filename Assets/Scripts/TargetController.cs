using System.Collections.Generic;
using UnityEngine;

public class TargetController : MonoBehaviour
{
    public GameObject blueBallPrefab;
    public Transform targetParent;
    public float spacing = 0.3f;
    public List<GameObject> targets = new List<GameObject>();

    void Start()
    {
        Debug.Log("TargetController Start called");
        GenerateTargets();
    }

    public GameObject visualSpherePrefab;

    void GenerateTargets()
    {
        Vector3 center = new Vector3(0, 1.0f, 2.5f); // Adjust as needed
        for (int y = -1; y <= 1; y++)
        {
            for (int x = -1; x <= 1; x++)
            {
                Vector3 pos = center + new Vector3(x * spacing, y * spacing, 0);

                // Create an empty parent for the target
                GameObject targetGroup = new GameObject("Target_" + targets.Count);
                targetGroup.transform.SetParent(targetParent);
                targetGroup.transform.position = pos;
                targetGroup.SetActive(false);

                // Instantiate actual blue ball for hit detection
                GameObject targetCore = Instantiate(blueBallPrefab, pos, Quaternion.identity, targetGroup.transform);
                targetCore.name = "Core";

                // Create 100 small spheres around the core visually
                for (int i = 0; i < 100; i++)
                {
                    Vector3 offset = Random.insideUnitSphere * 0.05f; // tightly clustered
                    GameObject visual = Instantiate(visualSpherePrefab, pos + offset, Quaternion.identity, targetGroup.transform);
                    visual.transform.localScale = Vector3.one * 0.015f; // small
                    visual.name = "Dot_" + i;
                }

                targets.Add(targetGroup);
                Debug.Log("Instantiated Target Group: " + targetGroup.name + " at " + pos);
            }
        }
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
            {
                Debug.Log($"Target {i} ACTIVATED at position: {targets[i].transform.position}");
            }
        }
    }



    public GameObject GetTarget(int index)
    {
        return (index >= 0 && index < targets.Count) ? targets[index] : null;
    }
}
