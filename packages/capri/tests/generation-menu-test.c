/* SPDX-License-Identifier: GPL-2.0-only */
/* Host-only UI selection tests; no storage, boot or device I/O. */
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct pxe_label {
	char *name, *menu;
	struct pxe_label *next;
};
struct pxe_menu {
	struct { struct pxe_label *first; } labels;
	char *default_label;
	int timeout, prompt;
};
struct bootmenu_data { int count, delay, active; };
struct cli_ch_state { int unused; };
enum bootmenu_key { BKEY_NONE, BKEY_UP, BKEY_DOWN, BKEY_SELECT, BKEY_QUIT };
#define DIV_ROUND_UP(n, d) (((n) + (d) - 1) / (d))
#define list_for_each_entry(pos, head, member) \
	for ((pos) = (head)->first; (pos); (pos) = (pos)->next)

static enum bootmenu_key keys[8];
static int position, length;
static const char *override_name;
static bool countdown_expires;

static const char *env_get(const char *name)
{
	assert(!strcmp(name, "pxe_label_override"));
	return override_name;
}
static void cli_ch_init(struct cli_ch_state *state) { state->unused = 0; }
static enum bootmenu_key bootmenu_loop(struct bootmenu_data *m, struct cli_ch_state *c)
{
	(void)m;
	(void)c;
	assert(position < length);
	return keys[position++];
}
static enum bootmenu_key bootmenu_autoboot_loop(struct bootmenu_data *m,
					       struct cli_ch_state *c)
{
	(void)c;
	if (countdown_expires) {
		m->delay = 0;
		return BKEY_SELECT;
	}
	m->delay = -1;
	return BKEY_NONE;
}
static int quiet_printf(const char *format, ...)
{
	(void)format;
	return 0;
}
#define printf quiet_printf
#include "../uboot/capri-generation-menu.h"
#undef printf

static void sequence(enum bootmenu_key first, enum bootmenu_key second)
{
	position = 0;
	length = 2;
	keys[0] = first;
	keys[1] = second;
}

int main(void)
{
	struct pxe_label second = {.name = "older", .menu = "Older generation"};
	struct pxe_label first = {.name = "latest", .next = &second};
	struct pxe_menu cfg = {
		.labels.first = &first, .default_label = "latest", .prompt = 1
	};
	sequence(BKEY_DOWN, BKEY_SELECT);
	assert(capri_generation_menu(&cfg) == &second);
	sequence(BKEY_UP, BKEY_SELECT);
	assert(capri_generation_menu(&cfg) == NULL); /* wrap to Back */
	sequence(BKEY_QUIT, BKEY_SELECT);
	assert(capri_generation_menu(&cfg) == NULL);
	cfg.default_label = "older";
	cfg.prompt = 0;
	assert(capri_generation_menu(&cfg) == &second);
	override_name = "latest";
	assert(capri_generation_menu(&cfg) == &first);
	override_name = "missing";
	assert(capri_generation_menu(&cfg) == &second); /* retain valid default */
	override_name = NULL;
	cfg.prompt = 1;
	cfg.timeout = 30;
	countdown_expires = true;
	assert(capri_generation_menu(&cfg) == &second);
	countdown_expires = false;
	sequence(BKEY_UP, BKEY_SELECT); /* interruption, then navigate */
	assert(capri_generation_menu(&cfg) == &first);
	cfg.labels.first = NULL;
	sequence(BKEY_SELECT, BKEY_QUIT);
	assert(capri_generation_menu(&cfg) == NULL);
	puts("PASS: Up/Down, Back, cancel, defaults, overrides, timeout and interruption");
	return 0;
}
