/*
  # Create files table for file management

  1. New Tables
    - `files`
      - `id` (uuid, primary key)
      - `name` (text, required) - Name of the file
      - `category_id` (uuid, optional) - Reference to categories table
      - `spreadsheet_url` (text, required) - URL to the spreadsheet/document
      - `description` (text, optional) - File description
      - `file_size` (integer, optional) - File size in bytes
      - `is_pinned` (boolean, default false) - Whether file is pinned
      - `created_by` (uuid, optional) - Reference to users table
      - `created_at` (timestamp) - Creation timestamp
      - `updated_at` (timestamp) - Last update timestamp

  2. Security
    - Enable RLS on `files` table
    - Add policies for authenticated users to manage files
    - Add policies for anonymous users to read files
    - Add policies for superadmins to manage all files

  3. Indexes
    - Index on category_id for filtering
    - Index on created_by for user-specific queries
    - Index on is_pinned for sorting pinned files
*/

-- Create files table
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
CREATE INDEX IF NOT EXISTS idx_files_updated_at ON files(updated_at);

-- Create trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER IF NOT EXISTS update_files_updated_at
  BEFORE UPDATE ON files
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE files ENABLE ROW LEVEL SECURITY;

-- Policy for anonymous users to read files
CREATE POLICY "Allow anonymous read files"
  ON files
  FOR SELECT
  TO anon
  USING (true);

-- Policy for authenticated users to read all files
CREATE POLICY "Authenticated users can read all files"
  ON files
  FOR SELECT
  TO authenticated
  USING (true);

-- Policy for authenticated users to manage their own files
CREATE POLICY "Users can manage own files"
  ON files
  FOR ALL
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- Policy for superadmins to manage all files
CREATE POLICY "Superadmins can manage all files"
  ON files
  FOR ALL
  TO authenticated
  USING (
    (jwt() ->> 'role' = 'superadmin') OR 
    ((jwt() -> 'user_metadata') ->> 'role' = 'superadmin')
  )
  WITH CHECK (
    (jwt() ->> 'role' = 'superadmin') OR 
    ((jwt() -> 'user_metadata') ->> 'role' = 'superadmin')
  );

-- Policy for superadmins to insert files
CREATE POLICY "Superadmins can insert files"
  ON files
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (jwt() ->> 'role' = 'superadmin') OR 
    ((jwt() -> 'user_metadata') ->> 'role' = 'superadmin')
  );

-- Policy for users to insert their own files
CREATE POLICY "Users can insert own files"
  ON files
  FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid());