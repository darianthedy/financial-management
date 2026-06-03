CREATE TABLE transaction_categories (
  transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  category_id    UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (transaction_id, category_id)
);

CREATE TABLE transaction_tags (
  transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  tag_id         UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (transaction_id, tag_id)
);
