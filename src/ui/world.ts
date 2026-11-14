import * as THREE from 'three';
import type { MissionState } from '../shared/types';
import { FINDING_COLORS, FINDING_LABELS } from './findings';

export function createWorld(container: HTMLElement, move: (dx: number, dz: number) => void) {
  const scene = new THREE.Scene();
  scene.background = new THREE.Color('#101b20');
  scene.fog = new THREE.Fog('#101b20', 36, 80);
  const camera = new THREE.PerspectiveCamera(42, 1, 0.1, 150);
  camera.position.set(21, 25, 26); camera.lookAt(0, 0, 0);
  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.shadowMap.enabled = true;
  container.append(renderer.domElement);
  renderer.domElement.setAttribute('aria-label', 'Lunar survey area. Use the arrow controls or WASD to move the rover.');
  scene.add(new THREE.HemisphereLight(0xb7cbd7, 0x283337, 2));
  const sun = new THREE.DirectionalLight(0xffe6bb, 3);
  sun.position.set(14, 18, 8); sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  Object.assign(sun.shadow.camera, { left: -20, right: 20, top: 20, bottom: -20 });
  scene.add(sun);
  const surface = new THREE.Mesh(new THREE.PlaneGeometry(26, 26, 40, 40), new THREE.MeshStandardMaterial({ color: 0x637077, roughness: 1, flatShading: true }));
  surface.rotation.x = -Math.PI / 2; surface.receiveShadow = true; scene.add(surface);
  const grid = new THREE.GridHelper(24, 24, 0x708b8a, 0x405052); grid.position.y = 0.03; scene.add(grid);
  const shade = new THREE.Mesh(new THREE.PlaneGeometry(10, 26), new THREE.MeshBasicMaterial({ color: 0x091523, transparent: true, opacity: 0.56 }));
  shade.rotation.x = -Math.PI / 2; shade.position.set(-8, 0.04, 0); scene.add(shade);
  for (let i = 0; i < 60; i++) {
    const x = Math.sin(i * 17.3) * 12; const z = Math.cos(i * 8.7) * 12;
    if (Math.abs(x) < 2 && Math.abs(z) < 2) continue;
    const rock = new THREE.Mesh(new THREE.DodecahedronGeometry(0.12 + (i % 5) * 0.07), new THREE.MeshStandardMaterial({ color: 0x798184, flatShading: true }));
    rock.position.set(x, 0.12, z); rock.rotation.set(i, i * 2, i); rock.castShadow = true; scene.add(rock);
  }
  const rover = new THREE.Group();
  const chassis = new THREE.Mesh(new THREE.BoxGeometry(0.85, 0.35, 1.2), new THREE.MeshStandardMaterial({ color: 0xe9e0c5 }));
  chassis.position.y = 0.48; chassis.castShadow = true; rover.add(chassis);
  for (const x of [-0.5, 0.5]) for (const z of [-0.42, 0.42]) {
    const wheel = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.22, 0.16, 12), new THREE.MeshStandardMaterial({ color: 0x18252b }));
    wheel.rotation.z = Math.PI / 2; wheel.position.set(x, 0.25, z); rover.add(wheel);
  }
  const mast = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.65, 0.08), new THREE.MeshStandardMaterial({ color: 0xefe5d5 }));
  mast.position.set(0, 0.9, -0.35); rover.add(mast);
  const eye = new THREE.Mesh(new THREE.BoxGeometry(0.32, 0.15, 0.16), new THREE.MeshStandardMaterial({ color: 0x72e3c7, emissive: 0x164d43 }));
  eye.position.set(0, 1.23, -0.35); rover.add(eye); scene.add(rover);
  const station = new THREE.Group();
  const module = new THREE.Mesh(new THREE.BoxGeometry(1.3, 0.8, 1.2), new THREE.MeshStandardMaterial({ color: 0xe5dfca }));
  module.position.y = 0.4; station.add(module);
  const panel = new THREE.Mesh(new THREE.BoxGeometry(2.3, 0.07, 1.1), new THREE.MeshStandardMaterial({ color: 0x255a8b, metalness: 0.4, roughness: 0.5 }));
  panel.position.set(0, 1, 0); station.add(panel); station.visible = false; scene.add(station);
  const markers = new THREE.Group(); scene.add(markers);
  const labels = new Map<string, { ring: THREE.Mesh; element: HTMLDivElement }>();
  const stationLabel = document.createElement('div');
  stationLabel.className = 'world-label station-label';
  stationLabel.textContent = 'Research station'; stationLabel.hidden = true; container.append(stationLabel);
  const projectLabel = (element: HTMLElement, x: number, z: number) => {
    camera.updateMatrixWorld();
    const projected = new THREE.Vector3(x, 0.9, z).project(camera);
    element.style.left = `${(projected.x * 0.5 + 0.5) * container.clientWidth}px`;
    element.style.top = `${(-projected.y * 0.5 + 0.5) * container.clientHeight}px`;
  };
  const earth = new THREE.Mesh(new THREE.SphereGeometry(2.5, 24, 24), new THREE.MeshStandardMaterial({ color: 0x4c9cbd, emissive: 0x17404e }));
  earth.position.set(-20, 13, -25); scene.add(earth);
  const resize = new ResizeObserver(() => {
    const { width, height } = container.getBoundingClientRect();
    camera.aspect = width / Math.max(height, 1); camera.updateProjectionMatrix(); renderer.setSize(width, height);
    camera.updateMatrixWorld();
    for (const { ring, element } of labels.values()) projectLabel(element, ring.position.x, ring.position.z);
    if (station.visible) projectLabel(stationLabel, station.position.x, station.position.z);
  });
  resize.observe(container);
  const keys = (e: KeyboardEvent) => {
    if (e.ctrlKey || e.altKey || e.metaKey) return;
    if (e.target instanceof HTMLElement && (/INPUT|SELECT|TEXTAREA/.test(e.target.tagName) || e.target.isContentEditable)) return;
    const directions: Record<string, [number, number]> = { w: [0, -1], ArrowUp: [0, -1], s: [0, 1], ArrowDown: [0, 1], a: [-1, 0], ArrowLeft: [-1, 0], d: [1, 0], ArrowRight: [1, 0] };
    const direction = directions[e.key] ?? directions[e.key.toLowerCase()];
    if (direction) { e.preventDefault(); move(...direction); }
  };
  window.addEventListener('keydown', keys);
  renderer.setAnimationLoop(() => renderer.render(scene, camera));
  return {
    update(state: MissionState) {
      rover.position.set(state.position.x, 0, state.position.z);
      station.visible = state.outpostDeployed && state.outpostPosition !== null;
      stationLabel.hidden = !station.visible;
      if (station.visible && state.outpostPosition) {
        station.position.set(state.outpostPosition.x, 0, state.outpostPosition.z);
        projectLabel(stationLabel, station.position.x, station.position.z);
      }
      const ids = new Set(state.sites.map(site => site.id));
      for (const [id, { ring, element }] of labels) {
        if (ids.has(id)) continue;
        ring.geometry.dispose(); (ring.material as THREE.Material).dispose();
        markers.remove(ring); element.remove(); labels.delete(id);
      }
      for (const site of state.sites) {
        if (!labels.has(site.id)) {
          const ring = new THREE.Mesh(new THREE.TorusGeometry(0.8, 0.04, 8, 32), new THREE.MeshBasicMaterial());
          ring.rotation.x = Math.PI / 2;
          const element = document.createElement('div'); element.className = 'world-label';
          markers.add(ring); container.append(element); labels.set(site.id, { ring, element });
        }
        const { ring, element } = labels.get(site.id)!;
        ring.position.set(site.x, 0.12, site.z);
        (ring.material as THREE.MeshBasicMaterial).color.set(FINDING_COLORS[site.finding]);
        element.textContent = `Signal ${site.id.toUpperCase()} · ${site.confidence}%`;
        element.dataset.finding = site.finding;
        element.setAttribute('aria-label', `${site.name}: ${FINDING_LABELS[site.finding]}, ${site.confidence}% confidence in this finding`);
        projectLabel(element, site.x, site.z);
      }
    }
  };
}
