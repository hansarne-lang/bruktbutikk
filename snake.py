#!/usr/bin/env python3
"""Snake i terminalen – bruk piltaster, q for å avslutte."""

import curses
import random
import time

WIDTH  = 40
HEIGHT = 20

def main(stdscr):
    curses.curs_set(0)
    stdscr.nodelay(True)
    stdscr.timeout(100)

    curses.start_color()
    curses.init_pair(1, curses.COLOR_GREEN,  curses.COLOR_BLACK)  # slange
    curses.init_pair(2, curses.COLOR_RED,    curses.COLOR_BLACK)  # mat
    curses.init_pair(3, curses.COLOR_YELLOW, curses.COLOR_BLACK)  # score
    curses.init_pair(4, curses.COLOR_WHITE,  curses.COLOR_BLACK)  # ramme

    def draw_border(win):
        win.attron(curses.color_pair(4))
        win.border()
        win.attroff(curses.color_pair(4))

    def new_food(snake):
        while True:
            f = (random.randint(1, HEIGHT - 2), random.randint(1, WIDTH - 2))
            if f not in snake:
                return f

    # Spillvindu
    win = curses.newwin(HEIGHT, WIDTH, 2, 2)
    win.keypad(True)

    snake = [(HEIGHT // 2, WIDTH // 2 - i) for i in range(3)]
    direction = (0, 1)
    food = new_food(snake)
    score = 0
    speed = 0.12

    while True:
        key = stdscr.getch()
        if key == ord('q'):
            break
        elif key == curses.KEY_UP    and direction != (1, 0):  direction = (-1, 0)
        elif key == curses.KEY_DOWN  and direction != (-1, 0): direction = (1, 0)
        elif key == curses.KEY_LEFT  and direction != (0, 1):  direction = (0, -1)
        elif key == curses.KEY_RIGHT and direction != (0, -1): direction = (0, 1)

        head = (snake[0][0] + direction[0], snake[0][1] + direction[1])

        # Kollisjon med vegg eller seg selv
        if (head[0] <= 0 or head[0] >= HEIGHT - 1 or
                head[1] <= 0 or head[1] >= WIDTH - 1 or
                head in snake):
            # Game over-skjerm
            win.clear()
            draw_border(win)
            msg  = f"  GAME OVER!  Score: {score}  "
            msg2 = "  Trykk 'r' for ny runde, 'q' for avslut  "
            win.addstr(HEIGHT // 2 - 1, max(1, (WIDTH - len(msg)) // 2),
                       msg, curses.color_pair(2) | curses.A_BOLD)
            win.addstr(HEIGHT // 2 + 1, max(1, (WIDTH - len(msg2)) // 2),
                       msg2, curses.color_pair(4))
            win.refresh()
            stdscr.nodelay(False)
            while True:
                k = stdscr.getch()
                if k == ord('q'):
                    return
                if k == ord('r'):
                    stdscr.nodelay(True)
                    snake     = [(HEIGHT // 2, WIDTH // 2 - i) for i in range(3)]
                    direction = (0, 1)
                    food      = new_food(snake)
                    score     = 0
                    speed     = 0.12
                    break
            continue

        snake.insert(0, head)
        if head == food:
            score += 10
            speed  = max(0.05, speed - 0.002)
            food   = new_food(snake)
        else:
            snake.pop()

        # Tegn
        win.clear()
        draw_border(win)

        # Mat
        win.attron(curses.color_pair(2) | curses.A_BOLD)
        win.addch(food[0], food[1], '*')
        win.attroff(curses.color_pair(2) | curses.A_BOLD)

        # Slange
        for i, seg in enumerate(snake):
            win.attron(curses.color_pair(1) | (curses.A_BOLD if i == 0 else 0))
            win.addch(seg[0], seg[1], 'O' if i == 0 else 'o')
            win.attroff(curses.color_pair(1) | curses.A_BOLD)

        win.refresh()

        # Score-linje over vinduet
        stdscr.attron(curses.color_pair(3) | curses.A_BOLD)
        stdscr.addstr(0, 2, f"  SNAKE  |  Score: {score}  |  [Piltaster] Flytt  [Q] Avslutt  ")
        stdscr.attroff(curses.color_pair(3) | curses.A_BOLD)
        stdscr.refresh()

        time.sleep(speed)


if __name__ == "__main__":
    curses.wrapper(main)
