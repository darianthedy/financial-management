-- Seed categories for development.
-- After signing up a test user via the Auth dashboard (http://127.0.0.1:54323),
-- replace '<test-user-uuid>' with the actual user UUID.

INSERT INTO categories (user_id, name, icon, color) VALUES
  ('<test-user-uuid>', 'Food & Dining',    '🍔', '#FF6B6B'),
  ('<test-user-uuid>', 'Transportation',    '🚗', '#4ECDC4'),
  ('<test-user-uuid>', 'Housing',           '🏠', '#45B7D1'),
  ('<test-user-uuid>', 'Entertainment',     '🎬', '#96CEB4'),
  ('<test-user-uuid>', 'Shopping',          '🛍️', '#FFEAA7'),
  ('<test-user-uuid>', 'Healthcare',        '🏥', '#DDA0DD'),
  ('<test-user-uuid>', 'Utilities',         '💡', '#98D8C8'),
  ('<test-user-uuid>', 'Salary',            '💰', '#52C41A'),
  ('<test-user-uuid>', 'Freelance',         '💻', '#1890FF'),
  ('<test-user-uuid>', 'Investment Return', '📈', '#722ED1');
