/*
 * Adds vim-like keyboard navigation.
 *
 * Currently supports:
 * - j (scroll down)
 * - k (scroll up)
 * - gg (scroll to top)
 * - G (scroll to bottom)
 */

let last_key = null;

class ContentItems {
  constructor() {
    this.items = document.getElementsByClassName("content-item");
    this.current_index = 0;

    if (this.items.length) {
      this.items[0].parentElement.classList.add("active");
    }
  }

  get current_item() {
    return this.items[this.current_index];
  }

  _traverse(delta) {
    this.current_index += delta;

    if (this.current_index >= this.items.length) {
      console.warn("Items exhausted (returning last item)");
      this.current_index = this.items.length - 1;
    } else if (this.current_index < 0) {
      console.warn("Items exhausted (returning first item)");
      this.current_index = 0;
    }

    return this.current_item;
  }

  next() {
    return this._traverse(1);
  }

  prev() {
    return this._traverse(-1);
  }

  begin() {
    this.current_index = 0;
    return this.current_item;
  }

  end() {
    this.current_index = this.items.length - 1;
    return this.current_item;
  }

  is_empty() {
    return this.items.length <= 0;
  }
}
let items = new ContentItems();

class KeyNav {
  constructor(listing) {
    this.listing = listing;
    this._vertical_scroll_px = 100;
    this._scroll_behavior = "smooth";
  }

  _is_scrolling() {
    return this.listing.is_empty();
  }

  _toggle_active_element(item) {
    item.parentElement.classList.toggle("active");
  }

  next() {
    if (this._is_scrolling()) {
      window.scrollBy({
        top: this._vertical_scroll_px,
        behavior: this._scroll_behavior,
      });
    } else {
      this._toggle_active_element(items.current_item);
      this._toggle_active_element(items.next());
    }
  }

  prev() {
    if (this._is_scrolling()) {
      window.scrollBy({
        top: -this._vertical_scroll_px,
        behavior: this._scroll_behavior,
      });
    } else {
      this._toggle_active_element(items.current_item);
      this._toggle_active_element(items.prev());
    }
  }

  begin() {
    if (this._is_scrolling()) {
      window.scroll(0, 0);
    } else {
      this._toggle_active_element(items.current_item);
      this._toggle_active_element(items.begin());
    }
  }

  end() {
    if (this._is_scrolling()) {
      window.scroll(0, document.body.scrollHeight);
    } else {
      this._toggle_active_element(items.current_item);
      this._toggle_active_element(items.end());
    }
  }
}
let keynav = new KeyNav(items);

document.addEventListener("keydown", (e) => {
  switch (e.key) {
    case "j":
      keynav.next();
      break;

    case "k":
      keynav.prev();
      break;

    case "g":
      if (last_key === "g") {
        keynav.begin();
      }
      break;

    case "G":
      keynav.end();
      break;

    case "Enter":
      if (items.current_item !== undefined) {
        window.location.href = items.current_item.href;
      }
      break;
  }

  last_key = e.key;
});
