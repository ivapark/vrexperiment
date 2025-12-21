using UnityEngine;

public class StartZoneDetector : MonoBehaviour
{
    public bool handIsInZone = false;

    void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("RightHand"))
        {
            handIsInZone = true;
            Debug.Log("Right hand entered StartZone");
        }
    }

    void OnTriggerExit(Collider other)
    {
        if (other.CompareTag("RightHand"))
        {
            handIsInZone = false;
            Debug.Log("Right hand exited StartZone");
        }
    }
}
