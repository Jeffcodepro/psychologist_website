#!/usr/bin/env python3
"""Retain current + rollback releases. Read-only unless --apply is supplied."""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")
REPOSITORY = "psychologist-website"
SERVICES = {"psychologist-app_web", "psychologist-release_migrate"}


def version(value):
    if not VERSION.fullmatch(value):
        raise ValueError("Use tags numéricas como 1.2.8; latest e IDs não são aceitos.")
    return tuple(map(int, value.split(".")))


def image_version(image):
    prefix = REPOSITORY + ":"
    value = image.removeprefix(prefix).split("@")[0] if image.startswith(prefix) else ""
    return value if VERSION.fullmatch(value) else None


def docker(*arguments):
    return subprocess.check_output(["docker", *arguments], text=True).strip()


def inventory():
    ids = docker("ps", "-aq").split()
    containers = json.loads(docker("inspect", *ids)) if ids else []
    images = [json.loads(line) for line in docker("image", "ls", REPOSITORY, "--format", "{{json .}}").splitlines() if line]
    return containers, images


def check_current(containers, current):
    active = [item for item in containers if (item.get("Config", {}).get("Labels") or {}).get("com.docker.swarm.service.name") == "psychologist-app_web" and item["State"]["Running"]]
    if len(active) != 1 or image_version(active[0]["Config"]["Image"]) != current or active[0]["State"].get("Health", {}).get("Status") != "healthy":
        raise ValueError("A versão atual deve ter exatamente um web ativo e healthy neste node. Nenhuma limpeza aplicada.")


def plan(root, current, rollback, containers, images):
    if version(current) <= version(rollback):
        raise ValueError("A versão de rollback deve ser anterior à atual.")
    root = root.resolve()
    releases = root / "releases"
    if releases.is_symlink() or not releases.is_dir():
        raise ValueError("Diretório de releases ausente ou apontando para outro caminho.")
    keep = {current, rollback}
    # Keep anything referenced by another service or a running/restarting container.
    for item in containers:
        service = (item.get("Config", {}).get("Labels") or {}).get("com.docker.swarm.service.name")
        candidate = image_version(item["Config"]["Image"])
        if candidate and (item["State"].get("Running") or item["State"].get("Restarting") or service not in SERVICES):
            keep.add(candidate)
    def obsolete(candidate):
        return candidate and candidate not in keep and version(candidate) < version(current)
    operations = []
    for item in containers:
        if obsolete(image_version(item["Config"]["Image"])):
            operations.append(("container", item["Id"]))
    for image in images:
        if image["Repository"] == REPOSITORY and VERSION.fullmatch(image["Tag"]) and obsolete(image["Tag"]):
            operations.append(("image", f"{REPOSITORY}:{image['Tag']}"))
    for path in sorted(releases.iterdir()):
        if not path.is_symlink() and path.is_dir() and VERSION.fullmatch(path.name) and obsolete(path.name):
            operations.append(("directory", str(path)))
    for path in sorted(root.iterdir()):
        match = re.fullmatch(r"rosemarydias-source-([0-9]+\.[0-9]+\.[0-9]+)\.tar\.gz(?:\.sha256)?", path.name)
        if match and not path.is_symlink() and path.is_file() and obsolete(match[1]):
            operations.append(("archive", str(path)))
    return operations, keep


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("/opt/rosemarydias"))
    parser.add_argument("--current", required=True)
    parser.add_argument("--rollback", required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    version(args.current); version(args.rollback)
    containers, images = inventory()
    check_current(containers, args.current)
    for tag in (args.current, args.rollback):
        docker("image", "inspect", f"{REPOSITORY}:{tag}")
        if not (args.root / "releases" / tag).is_dir():
            raise ValueError(f"Preserve o código de releases/{tag} antes de limpar as versões antigas.")
    operations, keep = plan(args.root, args.current, args.rollback, containers, images)
    print("Preservar: " + ", ".join(sorted(keep, key=version)))
    for kind, target in operations:
        print(f"{'Excluir' if args.apply else 'Seria excluído'} {kind}: {target}")
    if not args.apply:
        print("Prévia apenas. Revise e repita com --apply para executar. Banco, volumes, mídias, secrets e backups não entram na limpeza.")
        return
    fresh_containers, fresh_images = inventory()
    check_current(fresh_containers, args.current)
    fresh_plan, _ = plan(args.root, args.current, args.rollback, fresh_containers, fresh_images)
    if fresh_plan != operations:
        raise ValueError("O estado mudou durante a conferência. Execute a prévia novamente.")
    for kind, target in operations:
        if kind == "container":
            docker("container", "rm", target)  # no force, no volumes
        elif kind == "image":
            docker("image", "rm", target)  # remove only this tag; no prune/force
        elif kind == "directory":
            shutil.rmtree(target)
        else:
            Path(target).unlink()
    print("Limpeza concluída. Versão atual e rollback preservados.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError, OSError) as error:
        raise SystemExit(f"Interrompido: {error}")
