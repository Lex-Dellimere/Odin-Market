defmodule OdinMarket.Repo.Migrations.UsernamesAndVendorSubscriptions do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :username, :citext
      add :selling, :boolean, null: false, default: false
    end

    execute """
    UPDATE users
    SET username = 'member_' || substr(replace(id::text, '-', ''), 1, 12)
    WHERE username IS NULL
    """

    execute "UPDATE users SET role = 'member' WHERE role IN ('customer', 'vendor')"
    execute "ALTER TABLE users ALTER COLUMN role SET DEFAULT 'member'"

    alter table(:users) do
      modify :username, :citext, null: false
    end

    create unique_index(:users, [:username], name: "users_unique_username_index")

    alter table(:vendor_profiles) do
      add :stripe_subscription_id, :text
      add :stripe_price_id, :text
      add :subscription_status, :text, null: false, default: "none"
      add :current_period_end, :utc_datetime_usec
    end

    execute """
    UPDATE vendor_profiles
    SET status = 'suspended', subscription_status = 'none'
    WHERE stripe_subscription_id IS NULL
    """

    execute "ALTER TABLE listings ALTER COLUMN currency SET DEFAULT 'aud'"
    execute "ALTER TABLE orders ALTER COLUMN currency SET DEFAULT 'aud'"
  end

  def down do
    execute "ALTER TABLE users ALTER COLUMN role SET DEFAULT 'customer'"

    alter table(:vendor_profiles) do
      remove :current_period_end
      remove :subscription_status
      remove :stripe_price_id
      remove :stripe_subscription_id
    end

    drop_if_exists unique_index(:users, [:username], name: "users_unique_username_index")

    alter table(:users) do
      remove :selling
      remove :username
    end
  end
end
