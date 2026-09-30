# Workloads

What to run on the dev box, and what belongs on the separate [LKE cluster](https://github.com/idvoretskyi/akamai-lke-gpu-cluster).

| On this dev box | On the LKE cluster |
|---|---|
| SSH, tmux, coding agents, Git worktrees | Kubeflow and GPU platform services |
| Small CPU PyTorch experiments and unit tests | GPU training, inference, pipeline execution |
| Pipeline authoring/compilation, container builds | Scheduled workload pods, persistent lab volumes |
| Kubernetes clients and dashboard tunnels | Cluster monitoring and GPU management |

Use separate worktrees and distinct Compose project names, ports, and volumes for concurrent projects. Worktrees are not security boundaries. Scope agent credentials; Docker-group membership and sudo are privileged host access.

## Local LLM inference (optional)

Hosted agents are primary; a small local model helps offline or privacy-sensitive work. Nothing is installed by cloud-init. Models that fit in 16 GiB (Q4_K_M):

| Model | Tag | Size |
|---|---|---|
| Gemma 4 12B | `gemma4:12b` | 7.6 GB |
| Ornith 1.5 9B | `ornith-1.5:9b` | 6.6 GB |
| Granite 4.2 8B | `granite4.2:8b` | 5.3 GB |

```sh
curl -fsSL https://ollama.com/install.sh | sh   # listens on 127.0.0.1:11434
ollama run gemma4:12b
```

Keep it on localhost (`ssh -L 11434:127.0.0.1:11434 $USER-dev-box`), avoid running it beside heavy builds, and 27B+ models do not fit in 16 GiB.

## Python and PyTorch

Use a project-local environment with a Python version the chosen PyTorch supports, managed via mise rather than replacing Ubuntu's system Python:

```sh
python -m venv .venv
. .venv/bin/activate
python -m pip install torch --index-url https://download.pytorch.org/whl/cpu
python -c 'import torch; print(torch.__version__, torch.cuda.is_available())'
```

This is a CPU-only smoke setup. Pin dependencies, bound thread/DataLoader worker counts, and keep datasets and checkpoints on disk-backed paths, not a tmpfs `/tmp`.

## Remote Kubernetes access

The LKE repository owns cluster provisioning and kubeconfig. Obtain credentials securely and keep them out of Git. Always pass `--context` and `--namespace`.

```sh
kubectl config get-contexts
kubectl --context LAB_CONTEXT get nodes
kubectl --context LAB_CONTEXT --namespace NAMESPACE port-forward --address 127.0.0.1 svc/SERVICE 8080:SERVICE_PORT
```

Check `kubectl version --client` against the server and pin a compatible client with mise if needed. Forward dashboards through SSH to `127.0.0.1:8080`; never bind `0.0.0.0` or open notebooks in the firewall.

## Optional local k3s

k3s is installed but not started or enabled. Use `k3s-up` and `k3s-kubectl` for disposable experiments; keep full Kubeflow on LKE. `k3s-down` (the installed `k3s-killall.sh`) stops local containers and resets local networking without deleting cluster data. It does not touch LKE and is not `k3s-uninstall.sh`.
