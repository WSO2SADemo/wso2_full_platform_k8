# AI Coding Agent Instructions for WSO2 APIM Airbus Demo

This project deploys **WSO2 API Manager (APIM)** on Azure Kubernetes Service (AKS) with a distributed control plane and gateway architecture. AI agents must understand the multi-tier deployment model and component communication patterns.

## Architecture Overview

### Component Structure
```
INTERNET → NGINX Ingress (4.150.126.28) → [AKS Namespaces]
├── apim-cp (Control Plane): acp-wso2am-acp pods + Shared Database
├── apim-gw (Gateway): gw-wso2am-universal-gw pods + H2 Local DB
└── External: Azure MySQL (apim_db, shared_db)
```

**Critical Pattern**: Control Plane and Gateway use a shared `shared_db` for users/tenants (mutual trust zone). Gateway delegates key validation and throttling to Control Plane via cluster-internal HTTPS URLs: `acp-wso2am-acp-service.apim-cp.svc.cluster.local:9443`.

### Key Files & Their Purpose
- **`control-plane/acp-min.yaml`**: Control Plane Helm values - configures MySQL databases, gateway environment registration, TLS keystores
- **`gateway/gw-min.yaml`**: Gateway Helm values - configures H2 local DB, remote Control Plane connection URLs (`km.serviceUrl`, `throttling.serviceUrl`)
- **`k8gw/1.3.0-1-cp-enabled-values.yaml`**: APK (API Platform on Kubernetes) configuration - future/experimental CP integration
- **`security/{cp,gw}/`**: Keystores/truststores for mutual TLS between components
- **`control-plane/Dockerfile`, `gateway/Dockerfile`**: Add MySQL JDBC driver to base WSO2 images

## Deployment Workflows

### New Deployment
```bash
# 1. Prerequisites: AKS cluster + Azure MySQL configured
az aks get-credentials --resource-group <RG> --name <CLUSTER>

# 2. Verify namespace doesn't exist (or edit acp-min.yaml for namespace name)
kubectl get namespace apim-cp

# 3. Deploy Control Plane (2 replicas for HA)
helm install acp <WSO2_HELM_CHART> -f control-plane/acp-min.yaml -n apim-cp --create-namespace

# 4. Deploy Gateway (uses Control Plane's internal service URL)
helm install gw <WSO2_HELM_CHART> -f gateway/gw-min.yaml -n apim-gw --create-namespace

# 5. Verify both deployments
kubectl get pods -n apim-cp -w
kubectl get pods -n apim-gw -w
```

### Debugging Commands
- **Logs**: `kubectl logs -f <POD_NAME> -n apim-cp` (check for "WSO2 Carbon started" message)
- **Pod shell**: `kubectl exec -it <POD_NAME> -n apim-cp -- /bin/bash`
- **Service connectivity**: `kubectl exec -it <POD_NAME> -n apim-gw -- nc -zv acp-wso2am-acp-service.apim-cp.svc.cluster.local 9443`
- **Database test**: `kubectl exec -it <POD_NAME> -n apim-cp -- mysql -h <AZURE_MYSQL_HOST> -u apimadmin -p`

## Configuration Patterns

### Database URLs (JDBC)
**Pattern observed in `acp-min.yaml` lines 28-35:**
```yaml
url: "jdbc:mysql://airbus-ramindus-db.mysql.database.azure.com:3306/apim_db?useSSL=false&requireSSL=true&verifyServerCertificate=false&allowPublicKeyRetrieval=true"
```
- `requireSSL=true`: Enforces encryption (Azure MySQL mandatory)
- `verifyServerCertificate=false`: Skips cert validation (dev/test only - security risk in production)
- `allowPublicKeyRetrieval=true`: Required for MySQL 8.0+ authentication
- Two separate users: `apimadmin@<SERVER>` (apim_db), `sharedadmin@<SERVER>` (shared_db)

**When modifying**: Always keep both databases pointing to same Azure MySQL server. If changing credentials, update both username fields to `<USER>@<SERVER_NAME>` format.

### Gateway-to-Control Plane Communication
**Pattern in `gw-min.yaml` lines 27-36:**
```yaml
km:
  serviceUrl: "acp-wso2am-acp-service.apim-cp.svc.cluster.local"  # Key Mgmt
  servicePort: 9443
throttling:
  serviceUrl: "acp-wso2am-acp-service.apim-cp.svc.cluster.local"
  servicePort: 9443
  urls:
    - "acp-wso2am-acp-1-service.apim-cp.svc.cluster.local"
    - "acp-wso2am-acp-2-service.apim-cp.svc.cluster.local"
```

**Critical Detail**: These are Kubernetes internal DNS names. If modifying deployment names (e.g., "acp-wso2am-acp-service"), must update both `gw-min.yaml` AND the Control Plane's actual service names. Service discovery depends on `<SERVICE_NAME>.<NAMESPACE>.svc.cluster.local` format.

### TLS/Certificate Setup
**Security structure in `security/Key Generation Steps.txt`:**
- Each component (CP, GW) generates its own keystore with private key (`control-keystore.jks`, `gateway-keystore.jks`)
- Each component's certificate is imported into the other's truststore for mutual TLS
- SAN (Subject Alternative Names) includes both external domains (`airbus.am.wso2.com`) and internal Kubernetes DNS names
- Keystores referenced in YAML: `acp-min.yaml` line 17 (`control-keystore.jks`), `gw-min.yaml` line 15 (`gateway-keystore.jks`)

**When updating hostnames**: Regenerate keystores with new SANs; the Dockerfile copies keystores to images, so rebuild container images after updating keystores.

## Common Issues & Remediation

### SSL Connection Error to MySQL
**Symptom**: `ERROR: Connections using insecure transport are prohibited while --require_secure_transport=ON`

**Root Cause**: Azure MySQL requires `require_secure_transport=ON`. JDBC URL must have both:
- `requireSSL=true` (enforces SSL)
- `verifyServerCertificate=false` (or true with cert in truststore)

**Fix**: Update JDBC URL in `acp-min.yaml` (both apim_db and shared_db URLs) to include these parameters.

### Gateway Cannot Reach Control Plane
**Symptom**: Gateway pod logs show connection timeout to `acp-wso2am-acp-service.apim-cp.svc.cluster.local`

**Root Cause**: Service name mismatch or namespace isolation.

**Debug**:
```bash
kubectl get svc -n apim-cp  # Verify actual service name
kubectl describe svc acp-wso2am-acp-service -n apim-cp  # Check ports
```

**Fix**: Ensure `gw-min.yaml` serviceUrl exactly matches the Control Plane service name and namespace.

### Pod CrashLoopBackOff with No Logs
**Common Cause**: ImagePullBackOff before container starts.

**Check**:
```bash
kubectl describe pod <POD> -n apim-cp | grep Events
```

**Likely Fix**: If using custom images (e.g., `minurakariyawasam/wso2am-acp-custom`), verify image exists and no tag/digest mismatch in `acp-min.yaml` line 4-6.

## Extension Points

### Adding New Gateway Environment
In `acp-min.yaml`, the Control Plane registers gateway environments (lines 37-50). To add a new environment:
```yaml
- name: "NewEnvironment"
  type: "hybrid"
  gatewayType: "Regular"
  serviceName: "my-new-gw-service"  # Must exist in apim-gw namespace
  servicePort: 9443
  httpHostname: "new-gw.wso2.com"
```

Then deploy the new gateway with matching service name and update DNS/Ingress accordingly.

### Scaling Control Plane for HA
Current setup: 2 replicas (acp-deployment-1, acp-deployment-2). They share `shared_db` for session management. To add more: scale the deployment and ensure Azure MySQL connection pooling accommodates more pod connections (default: ~20 connections per pod).

### Switching Databases
If migrating from Azure MySQL to another database:
1. Update JDBC driver in `control-plane/Dockerfile` and `gateway/Dockerfile`
2. Update JDBC URLs in `acp-min.yaml` (connection string format differs per DB)
3. Update userStore type if needed (currently `database_unique_id`)
4. Rebuild Docker images and update image digest in YAML files

## Non-Discoverable Developer Patterns

1. **Image Digest Pinning**: Uses `digest:` SHA256 instead of tags for reproducible builds (lines 6 in both min.yaml files). Update digest when rebuilding custom images.

2. **Kubernetes Internal URLs**: Gateway communicates with Control Plane using cluster-internal DNS (`*.apim-cp.svc.cluster.local`), not external Ingress hostname. This is intentional for security.

3. **Shared Database Strategy**: Both CP and GW must access `shared_db` for user/tenant data. The Gateway uses local H2 for its own state; it reads from `shared_db` only for user validation. Design your changes knowing CP is single source of truth.

4. **Ingress Hostname Registration**: External hostnames (`mbcp.am.wso2.com`, `airbus.gw.wso2.com`) are defined in Ingress resource, not in YAML values. Update Ingress separately if changing external URLs.

## References

- [WSO2 APIM Docs](https://apim.docs.wso2.com/)
- [Kubernetes API](https://kubernetes.io/docs/reference/generated/kubernetes-api/)
- [Azure MySQL Documentation](https://docs.microsoft.com/en-us/azure/mysql/)
