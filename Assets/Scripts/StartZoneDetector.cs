using UnityEngine;

public class StartZoneDetector : MonoBehaviour
{
    public bool handIsInZone = false;

    void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("RightHand")) // or check name/layer if needed
        {
            Debug.Log("Right hand entered StartZone");
            handIsInZone = true;
        }
    }


    void OnTriggerExit(Collider other)
    {
        if (other.CompareTag("RightHand"))
            handIsInZone = false;
    }

    void OnDrawGizmos()
    {
        Gizmos.color = Color.green;
        Gizmos.DrawWireSphere(transform.position, 0.1f);
    }
}
