using UnityEngine;

public class StartZoneTrigger : MonoBehaviour
{
    public bool handIsInZone = false;

    void OnTriggerEnter(Collider other)
    {
        Debug.Log("Entered by: " + other.name);
        if (other.CompareTag("RightHand"))
        {
            handIsInZone = true;
            Debug.Log("Controller entered start zone.");
        }
    }


    void OnTriggerExit(Collider other)
    {
        if (other.CompareTag("RightHand"))
        {
            handIsInZone = false;
            Debug.Log("Controller exited start zone.");
        }
    }
    void OnDrawGizmos()
    {
        Gizmos.color = Color.green;
        Gizmos.DrawWireSphere(transform.position, 0.1f); // adjust radius if needed
    }

}
