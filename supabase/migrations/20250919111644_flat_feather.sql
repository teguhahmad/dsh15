/*
  # Create files table for file management

  1. New Tables
    - `files`
      - `id` (uuid, primary key)
      - `name` (text, not null) - File name
      - `category_id` (uuid, foreign key) - Reference to categories table
      - `spreadsheet_url` (text, not null) - URL to the spreadsheet/document
      - `description` (text, nullable) - Optional file description
      - `file_size` (integer, nullable) - File size in bytes
      - `is_pinned` (boolean, default false) - Whether file is pinned
      - `created_by` (uuid, foreign key) - User who created the file
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on `files` table
    - Add policies for authenticated users to manage files
    - Add policies for anonymous users to read files

  3. Indexes
    - Index on category_id for faster filtering
    - Index on created_by for user-specific queries
    - Index on is_pinned for pinned files queries
*/

CREATE TABLE IF NOT EXISTS files (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  category_id uuid REFERENCES categories(id) ON DELETE SET NULL,
  spreadsheet_url text NOT NULL,
  description text,
  file_size integer,
  is_pinned boolean DEFAULT false,
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_files_category_id ON files(category_id);
CREATE INDEX IF NOT EXISTS idx_files_created_by ON files(created_by);
CREATE INDEX IF NOT EXISTS idx_files_is_pinned ON files(is_pinned);
CREATE INDEX IF NOT EXISTS idx_files_updated_at ON files(updated_at DESC);

-- Enable Row Level Security
ALTER TABLE files ENABLE ROW LEVEL SECURITY;

-- Policies for authenticated users
CREATE POLICY "Authenticated users can read all files"
  ON files
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Superadmins can manage all files"
  ON files
  FOR ALL
  TO authenticated
  USING (
    ((jwt() ->> 'role'::text) = 'superadmin'::text) OR 
    (((jwt() -> 'user_metadata'::text) ->> 'role'::text) = 'superadmin'::text)
  )
  WITH CHECK (
    ((jwt() ->> 'role'::text) = 'superadmin'::text) OR 
    (((jwt() -> 'user_metadata'::text) ->> 'role'::text) = 'superadmin'::text)
  );

CREATE POLICY "Users can manage their own files"
  ON files
  FOR ALL
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- Policies for anonymous users (read-only access)
CREATE POLICY "Anonymous users can read all files"
  ON files
  FOR SELECT
  TO anon
  USING (true);

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_files_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
CREATE TRIGGER update_files_updated_at_trigger
  BEFORE UPDATE ON files
  FOR EACH ROW
  EXECUTE FUNCTION update_files_updated_at();