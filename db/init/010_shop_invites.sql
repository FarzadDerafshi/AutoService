CREATE TABLE shop_invites (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id     UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    role        user_role NOT NULL,
    -- Nullable + ON DELETE SET NULL (not RESTRICT): these are audit
    -- pointers to "who created/used this invite," not data the invite
    -- depends on. A manager who created invites, or a teammate who
    -- accepted one, must still be deletable later — see DECISIONS.md.
    created_by  UUID REFERENCES users(id) ON DELETE SET NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    used_at     TIMESTAMPTZ,
    used_by     UUID REFERENCES users(id) ON DELETE SET NULL,
    revoked_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_shop_invites_shop_id ON shop_invites(shop_id);
