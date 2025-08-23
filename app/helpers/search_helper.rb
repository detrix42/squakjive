module SearchHelper
  def first_visible(idx)
    "first-visible" if idx == 0
  end

  def last_visible(idx, available_users)
    "last-visible" if idx == available_users.count - 1
  end

  # Compose the full class string for a list-group item
  def list_group_item_classes(idx, collection, base: "list-group-item list-group-item-action")
    classes = [base]
    classes << first_visible(idx)
    classes << last_visible(idx, collection)
    classes.compact.join(" ")
  end
end
