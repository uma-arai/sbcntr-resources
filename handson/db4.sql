-- 新規に作成する pets マスタ
CREATE TABLE pets
(
    id               TEXT PRIMARY KEY,
    name             TEXT    NOT NULL,
    breed            TEXT    NOT NULL,
    gender           TEXT    NOT NULL,
    price            NUMERIC NOT NULL,
    image_url        TEXT,
    likes            INTEGER NOT NULL,
    shop_name        TEXT    NOT NULL,
    shop_location    TEXT   NOT NULL,
    birth_date       DATE,
    reference_number TEXT   NOT NULL,
    tags             TEXT[]  NOT NULL,
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 新規に作成する reservations テーブル
CREATE TABLE IF NOT EXISTS reservations
(
    -- 予約ごとに一意のIDを持たせる (UUID, SERIALなど)
    id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- ユーザを識別するID（外部の認証IDや社内システムIDなど任意）
    user_id        TEXT    NOT NULL,
    -- ユーザの氏名
    user_name      TEXT    NOT NULL,
    -- ユーザのメールアドレス
    email          TEXT    NOT NULL,
    -- 見学予定日時
    reservation_date_time TIMESTAMP NOT NULL,
    -- 予約ステータス pending, confirmed, cancelled
    status TEXT NOT NULL,
    -- 予約対象のペットID
    -- petsテーブルのidを参照 (FK)
    pet_id         TEXT    NOT NULL REFERENCES pets (id) ON DELETE CASCADE,
    -- 予約レコードが作られた日時
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- 予約レコードが更新された日時
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- お気に入りを管理するテーブル
CREATE TABLE IF NOT EXISTS favorites
(
    -- 予約ごとに一意のIDを持たせる (UUID, SERIALなど)
    id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- ユーザを識別するID（外部の認証IDや社内システムIDなど任意）
    user_id        TEXT    NOT NULL,
    -- 予約対象のペットID
    -- petsテーブルのidを参照 (FK)
    pet_id         TEXT    NOT NULL REFERENCES pets (id) ON DELETE CASCADE
);

-- 通知を管理するテーブル
CREATE TABLE IF NOT EXISTS notifications
(
    -- 通知ごとに一意のIDを持たせる
    id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- ユーザを識別するID
    user_id        TEXT    NOT NULL,
    -- 通知のタイトル
    title          TEXT    NOT NULL,
    -- 通知のメッセージ内容
    message        TEXT    NOT NULL,
    -- 既読状態
    is_read        BOOLEAN NOT NULL DEFAULT FALSE,
    -- 通知の種類
    type           TEXT    NOT NULL,
    -- 通知レコードが作られた日時
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- 通知レコードが更新された日時
    updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for reservations table
CREATE INDEX idx_reservations_pet_id ON reservations(pet_id);
CREATE INDEX idx_reservations_user_id ON reservations(user_id);
CREATE INDEX idx_reservations_status ON reservations(status);
-- Indexes for favorites table
CREATE INDEX idx_favorites_user_id ON favorites(user_id);
-- Composite unique index to ensure one favorite per user-pet combination
CREATE UNIQUE INDEX idx_favorites_user_pet ON favorites(user_id, pet_id);
-- Indexes for notifications table
CREATE INDEX idx_notifications_user_id ON notifications(user_id);