/*
 * Adds vim-like keyboard navigation.
 *
 * Currently supports:
 * - j (scroll down)
 * - k (scroll up)
 * - gg (scroll to top)
 * - G (scroll to bottom)
 */

const scroll_vertical = 100;
const scroll_behavior = "smooth";
let last_key = null;

document.addEventListener("keydown", (e) => {
  console.log(e);

  let scroll_factor = 1;

  if (e.key === "k") {
    scroll_factor *= -1;
  }

  switch (e.key) {
    case "j":
    case "k":
      window.scrollBy({
        top: scroll_factor * scroll_vertical,
        behavior: scroll_behavior,
      });
      break;

    case "g":
      if (last_key === "g") {
        window.scroll(0, 0);
      }
      break;

    case "G":
      window.scroll(0, document.body.scrollHeight);
      break;
  }

  last_key = e.key;
});
