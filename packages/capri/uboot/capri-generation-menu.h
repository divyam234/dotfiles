/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Button-driven extlinux picker for Capri's framebuffer console.
 * Uses the same key decoder as bootmenu (button-kbd: Up/Down/Enter).
 * NULL means Back/cancel, never "try other generations".
 */
static struct pxe_label *capri_generation_menu(struct pxe_menu *cfg)
{
	struct bootmenu_data menu = { 0 };
	struct cli_ch_state cch;
	struct pxe_label *label, **labels, *choice = NULL;
	const char *override = env_get("pxe_label_override");
	int count = 0, i;
	bool redraw = true;

	list_for_each_entry(label, &cfg->labels, list)
		count++;
	labels = calloc(count + 1, sizeof(*labels));
	if (!labels)
		return NULL;
	i = 0;
	list_for_each_entry(label, &cfg->labels, list) {
		labels[i] = label;
		if (cfg->default_label && !strcmp(cfg->default_label, label->name))
			menu.active = i;
		i++;
	}
	for (i = 0; override && i < count; i++)
		if (!strcmp(override, labels[i]->name))
			menu.active = i;
	menu.count = count + 1; /* Last entry is Back, including an empty config. */
	menu.delay = cfg->prompt ?
		(cfg->timeout ? DIV_ROUND_UP(cfg->timeout, 10) : -1) : 0;
	if (!count)
		menu.delay = -1;
	cli_ch_init(&cch);
	printf("\033[?25l");
	for (;;) {
		enum bootmenu_key key;

		if (redraw) {
			printf("\033[2J\033[H\n  NixOS generations\n\n");
			for (i = 0; i < menu.count; i++) {
				const char *title = i == count ? "Back to main menu" :
					(labels[i]->menu ? labels[i]->menu : labels[i]->name);

				printf("  %s %.72s \033[0m\n",
				       i == menu.active ? "\033[7m" : "", title);
			}
			printf("\n\n  Volume Up/Down: move   Power: select\n");
			redraw = false;
		}
		if (!menu.delay)
			key = BKEY_SELECT;
		else if (menu.delay > 0)
			key = bootmenu_autoboot_loop(&menu, &cch);
		else
			key = bootmenu_loop(&menu, &cch);
		if (key == BKEY_UP) {
			menu.active = (menu.active + menu.count - 1) % menu.count;
			redraw = true;
		} else if (key == BKEY_DOWN) {
			menu.active = (menu.active + 1) % menu.count;
			redraw = true;
		} else if (key == BKEY_SELECT) {
			choice = labels[menu.active];
			break;
		} else if (key == BKEY_QUIT) {
			break;
		}
	}
	printf("\033[0m\033[?25h\033[2J\033[H");
	free(labels);
	return choice;
}
