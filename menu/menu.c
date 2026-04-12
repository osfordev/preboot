//
// gcc -march=x86-64 -mtune=generic -static menu.c -o menu -lmenu -lncurses -ltinfo
//


#include <stdlib.h>
#include <string.h>

#include <menu.h>

#define ARRAY_SIZE(a) (sizeof(a) / sizeof(a[0]))
#define CTRLD 	4

void print_in_middle(WINDOW *win, int starty, int startx, int width, char *string, chtype color);

int main(int argc, char *argv[]) {
	if(argc <= 1) {
		return 255;
	}
	else if( argc == 2 ) {
		printf("The argument supplied is %s\n", argv[1]);
		return 0;
	}

	ITEM **my_items;
	int c;
	MENU *my_menu;
	WINDOW *my_menu_win;
	int n_choices, i;

	/* Initialize curses */
	initscr();
	start_color();
	cbreak();
	noecho();
	keypad(stdscr, TRUE);
	init_pair(1, COLOR_RED, COLOR_BLACK);

	/* Initialize items */
	// n_choices = ARRAY_SIZE(choices);
	n_choices = argc - 1;
	my_items = (ITEM **)calloc(n_choices + 1, sizeof(ITEM *));
	for (i = 0; i < n_choices; ++i) {
		// my_items[i] = new_item(choices[i], "");
		my_items[i] = new_item(argv[i+1], "");
	}
	my_items[n_choices] = (ITEM *)NULL;

	/* Crate menu */
	my_menu = new_menu((ITEM **)my_items);

	/* Create the window to be associated with the menu */
	my_menu_win = newwin(10, 40, 4, 4);
	keypad(my_menu_win, TRUE);

	/* Set main window and sub window */
	set_menu_win(my_menu, my_menu_win);
	set_menu_sub(my_menu, derwin(my_menu_win, 6, 38, 3, 1));

	/* Set menu mark to the string " * " */
	set_menu_mark(my_menu, " * ");

	/* Print a border around the main window and print a title */
	box(my_menu_win, 0, 0);
	print_in_middle(my_menu_win, 1, 0, 40, "Select OS Version", COLOR_PAIR(1));
	mvwaddch(my_menu_win, 2, 0, ACS_LTEE);
	mvwhline(my_menu_win, 2, 1, ACS_HLINE, 38);
	mvwaddch(my_menu_win, 2, 39, ACS_RTEE);
	refresh();

	/* Post the menu */
	post_menu(my_menu);
	wrefresh(my_menu_win);

	int current_item_index = -1;
	while(current_item_index == -1)
	{
		c = getch();
		switch(c) {
			case KEY_DOWN:
				menu_driver(my_menu, REQ_DOWN_ITEM);
				break;
			case KEY_UP:
				menu_driver(my_menu, REQ_UP_ITEM);
				break;
			case 10: /* Enter */
				move(20, 0);
				clrtoeol();
				current_item_index = item_index(current_item(my_menu));
				// mvprintw(20, 0, "Item selected is : %d", current_item_index);
				// pos_menu_cursor(my_menu);
				break;
		}
		if (current_item_index != -1) {
			break;
		}
		wrefresh(my_menu_win);
	}

	/* Unpost and free all the memory taken up */
	unpost_menu(my_menu);
	free_menu(my_menu);
	for(i = 0; i < n_choices; ++i) {
		free_item(my_items[i]);
	}
	endwin();

	return current_item_index;
}

void print_in_middle(WINDOW *win, int starty, int startx, int width, char *string, chtype color)
{	int length, x, y;
	float temp;

	if(win == NULL)
		win = stdscr;
	getyx(win, y, x);
	if(startx != 0)
		x = startx;
	if(starty != 0)
		y = starty;
	if(width == 0)
		width = 80;

	length = strlen(string);
	temp = (width - length)/ 2;
	x = startx + (int)temp;
	wattron(win, color);
	mvwprintw(win, y, x, "%s", string);
	wattroff(win, color);
	refresh();
}
