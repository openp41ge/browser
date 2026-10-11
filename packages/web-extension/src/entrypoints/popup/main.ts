import { featureEnabledItem } from '@/core/settings';
import { features } from '@/features';

const list = document.querySelector<HTMLUListElement>('#features')!;

for (const feature of features) {
  const enabled = featureEnabledItem(feature);

  const item = document.createElement('li');
  item.innerHTML = `
    <label>
      <input type="checkbox" />
      <span>
        <div class="name"></div>
        <div class="description"></div>
      </span>
    </label>
  `;
  item.querySelector('.name')!.textContent = feature.name;
  item.querySelector('.description')!.textContent = feature.description;

  const checkbox = item.querySelector('input')!;
  enabled.getValue().then((value) => (checkbox.checked = value));
  checkbox.addEventListener('change', () => enabled.setValue(checkbox.checked));

  list.append(item);
}
