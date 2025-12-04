# User Roles and Permissions Implementation

This document describes the user roles and permissions system implemented in Flow Manager.

## Architecture Note

The user profile and permissions system is implemented at the **application level** (in the example app) rather than as part of the core Flow Manager package. This is because:

- User management is application-specific logic, not core flow functionality
- Different applications may have different user models and permission systems
- The Flow Manager package focuses on flow creation, editing, and playback
- The Supabase schema is provided as a reference implementation for applications that choose to use it

## User Roles

The system implements four distinct user roles with different levels of access and capabilities:

### 1. Viewer
- **Description**: Can view and play flows but cannot create or modify them
- **Permissions**:
  - ✅ View flows
  - ✅ Play/navigate through flows
  - ✅ Delete local flows (including downloaded flows)
  - ❌ Create new flows
  - ❌ Edit existing flows
  - ❌ Change flow state (approve/reject)
  - ❌ Archive cloud flows
  - ❌ Share flows
  - ❌ Upload flows to cloud
  - ❌ Manage users

### 2. Editor (Default Role)
- **Description**: Can create, edit, and manage flows but cannot change flow state
- **Permissions**:
  - ✅ View flows
  - ✅ Play/navigate through flows
  - ✅ Create new flows
  - ✅ Edit existing flows
  - ✅ Delete local flows (including downloaded flows)
  - ✅ Share flows
  - ✅ Upload flows to cloud
  - ❌ Change flow state (approve/reject)
  - ❌ Archive cloud flows
  - ❌ Manage users

### 3. Reviewer
- **Description**: Can review flows and change their state but cannot create new flows
- **Permissions**:
  - ✅ View flows (all flows)
  - ✅ Play/navigate through flows
  - ✅ Delete local flows (including downloaded flows)
  - ✅ Change flow state (approve/reject)
  - ✅ Archive cloud flows (cloud flows cannot be deleted, only archived)
  - ❌ Create new flows
  - ❌ Edit flows
  - ❌ Share flows
  - ❌ Upload flows to cloud
  - ❌ Manage users

### 4. Admin
- **Description**: Full access - can create, edit, review flows and manage users
- **Permissions**:
  - ✅ View flows (all flows)
  - ✅ Play/navigate through flows
  - ✅ Create new flows
  - ✅ Edit flows (any flow)
  - ✅ Delete local flows (including downloaded flows)
  - ✅ Archive cloud flows (cloud flows cannot be deleted, only archived)
  - ✅ Share flows
  - ✅ Upload flows to cloud
  - ✅ Change flow state (approve/reject/archive)
  - ✅ Manage users (change roles, activate/deactivate)

## Flow Deletion Rules

The system implements specific rules for flow deletion based on storage location:

### Local Flows
- **Who can delete**: All users (Viewer, Editor, Reviewer, Admin)
- **What can be deleted**: Any local flow including downloaded flows from cloud
- **How**: Permanent deletion from local storage
- **Rationale**: Local flows are under user's control and don't affect other users

### Cloud Flows
- **Who can archive**: Only Reviewers and Admins
- **What happens**: Flows are marked as archived, not deleted
- **How**: Set flow status to 'archived' in database
- **Rationale**: Cloud flows may be referenced by other users and should be preserved for audit trails

> **Important**: Cloud flows can never be truly deleted to maintain data integrity and audit trails. They can only be archived by users with review permissions.

## Database Schema

### User Profiles Table

```sql
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT,
    role TEXT NOT NULL DEFAULT 'editor' CHECK (role IN ('viewer', 'editor', 'reviewer', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    department TEXT
);
```

### Row Level Security (RLS) Policies

The system implements comprehensive RLS policies to enforce role-based permissions:

- Users can view their own profiles
- Admins can view all profiles
- Users can update their own profile (but not their role)
- Admins can update any profile including roles
- Flow access is restricted based on user roles

## Implementation Files

### Core Models
- `example/lib/models/user_profile.dart` - UserProfile model and UserRole enum (application-level)
- `example/lib/services/user_profile_service.dart` - Service for managing user profiles (application-level)
- `example/lib/services/auth_service_extensions.dart` - Extensions to AuthService for role-based permissions

### Database Schema
- `supabase/user_profiles_schema.sql` - Complete database schema and policies

### Integration
- `example/lib/services/auth_service.dart` - Extended with user profile integration
- `example/lib/screens/home_screen.dart` - Updated to respect user permissions

## Usage Examples

### Check User Permissions

```dart
// Check if current user can create flows
final canCreate = await authService.canCreateFlows;

// Check specific permission
final canManage = await authService.hasPermission('manage_users');

// Get current user role
final role = authService.currentUserRole;
```

### Conditional UI Based on Permissions

```dart
// Disable flow creation for viewers
FlowListView(
  enableFlowCreation: await authService.canCreateFlows,
  // ... other parameters
)

// Show admin panel only for admins
if (await authService.canManageUsers) {
  // Show admin UI
}
```

### Working with User Profiles

```dart
// Import the application-level models and services
import 'models/user_profile.dart';
import 'services/user_profile_service.dart';
import 'services/auth_service_extensions.dart';

final userProfileService = UserProfileService();

// Get current user profile
final profile = await userProfileService.getCurrentUserProfile();

// Update user role (admin only)
await userProfileService.updateUserRole(userId, UserRole.reviewer);

// Get users by role
final editors = await userProfileService.getUsersByRole(UserRole.editor);
```

## Setup Instructions

### 1. Database Setup

Run the user profiles schema in your Supabase instance:

```sql
-- Run the contents of supabase/user_profiles_schema.sql
```

### 2. Create Initial Admin User

After a user signs up, promote them to admin:

```sql
SELECT create_admin_user('admin@yourcompany.com');
```

### 3. Integration in Your App

The AuthService automatically loads user profiles when users sign in. No additional setup is required in the app code.

## Offline Mode Behavior

When in offline mode (no Supabase connection):
- All users are treated as having "Editor" permissions
- User profile features are disabled
- Flow creation and editing are allowed
- State management features are not available

## Security Considerations

1. **Role Changes**: Only admins can change user roles
2. **Profile Access**: Users can only see their own profiles (except admins)
3. **Flow State**: Only reviewers and admins can change flow approval status
4. **Database Policies**: All permissions are enforced at the database level via RLS

## Future Enhancements

Potential areas for extension:

1. **Custom Permissions**: Fine-grained permissions beyond the basic roles
2. **Department-based Access**: Restrict access based on user departments
3. **Time-based Roles**: Temporary role assignments
4. **Audit Logging**: Track role changes and permission usage
5. **Role Hierarchies**: More complex role relationships

## Migration Notes

For existing installations:

1. User profiles are automatically created when users sign in after the schema is deployed
2. All existing users will default to "Editor" role
3. Manually promote required users to Admin role
4. No data migration is required for existing flows
