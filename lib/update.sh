#!/usr/bin/env bash

update_project() {
  UPDATE_APPLIED=0
  command_exists git || { warn "Git no está instalado."; return 1; }
  git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    warn "Esta instalación no proviene de Git y no puede actualizarse automáticamente."
    return 1
  }
  [[ -z $(git -C "$PROJECT_ROOT" status --porcelain) ]] || {
    warn "Hay cambios locales. Guárdelos o descártelos antes de actualizar."
    git -C "$PROJECT_ROOT" status --short
    return 1
  }

  info "Buscando commits nuevos en GitHub..."
  git -C "$PROJECT_ROOT" fetch --quiet origin main || {
    warn "No se pudo consultar origin/main. Revise Internet y el remoto Git."
    return 1
  }

  local local_sha remote_sha base_sha
  local_sha=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
  remote_sha=$(git -C "$PROJECT_ROOT" rev-parse FETCH_HEAD)
  base_sha=$(git -C "$PROJECT_ROOT" merge-base HEAD FETCH_HEAD)
  printf '  Instalada: %s\n  Disponible: %s\n' "${local_sha:0:8}" "${remote_sha:0:8}"

  if [[ $local_sha == "$remote_sha" ]]; then
    info "Ya tiene la versión más reciente."
    return 0
  fi
  if [[ $base_sha != "$local_sha" ]]; then
    warn "El historial local diverge de GitHub; actualización automática cancelada."
    return 1
  fi

  printf '\nCommits disponibles:\n'
  git -C "$PROJECT_ROOT" log --oneline --no-decorate HEAD..FETCH_HEAD
  printf '\n'
  confirm "¿Instalar esta actualización?" || { info "Actualización cancelada."; return 0; }
  git -C "$PROJECT_ROOT" merge --ff-only FETCH_HEAD
  find "$PROJECT_ROOT" -maxdepth 1 -type f -name '*.sh' -exec chmod 755 {} +
  [[ ! -d $PROJECT_ROOT/lib ]] || find "$PROJECT_ROOT/lib" -maxdepth 1 -type f -name '*.sh' -exec chmod 755 {} +
  UPDATE_APPLIED=1
  log_event "project updated to ${remote_sha:0:12}"
  info "Actualización instalada correctamente."
}
