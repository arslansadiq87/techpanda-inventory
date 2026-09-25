import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/stock_line_draft.dart';
import '../widgets/error_banner.dart';
import '../widgets/inventory_badges.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({
    super.key,
    required this.api,
    required this.error,
    required this.projects,
    required this.components,
    required this.activeProject,
    required this.projectNameController,
    required this.newProjectDescriptionController,
    required this.activeProjectDescriptionController,
    required this.projectViewMode,
    required this.exportingProjectId,
    required this.expandedProjectIds,
    required this.loadingProjectListIds,
    required this.projectListComponents,
    required this.projectListErrors,
    required this.projectDraftLines,
    required this.loadingProjectComponents,
    required this.savingProjectComponents,
    required this.projectComponentsDirty,
    required this.savingProjectDescription,
    required this.projectDescriptionDirty,
    required this.uploadingProjectImage,
    required this.showAllProjectComponents,
    required this.canCaptureProjectImage,
    required this.onCreateProject,
    required this.onOpenProject,
    required this.onEditProject,
    required this.onDeleteProject,
    required this.onExportProjectPdf,
    required this.onToggleProjectListComponents,
    required this.onLoadProjectListComponents,
    required this.onCloseProject,
    required this.onUploadProjectImage,
    required this.onSaveProjectDescription,
    required this.onLoadProjectComponents,
    required this.onSaveProjectComponents,
    required this.onAddProjectDraftLine,
    required this.onRemoveProjectDraftLine,
    required this.onAdjustProjectDraftQuantity,
    required this.onProjectComponentsDirtyChanged,
    required this.onProjectDescriptionDirtyChanged,
    required this.onShowAllProjectComponentsChanged,
    required this.onProjectSearchControllerChanged,
    required this.buildComponentThumbnail,
    required this.buildInventoryImage,
    required this.projectLineAsComponent,
  });

  final ApiClient api;
  final String? error;
  final List<dynamic> projects;
  final List<dynamic> components;
  final Map<String, dynamic>? activeProject;
  final TextEditingController projectNameController;
  final TextEditingController newProjectDescriptionController;
  final TextEditingController activeProjectDescriptionController;
  final String projectViewMode;
  final String? exportingProjectId;
  final Set<String> expandedProjectIds;
  final Set<String> loadingProjectListIds;
  final Map<String, List<Map<String, dynamic>>> projectListComponents;
  final Map<String, String> projectListErrors;
  final List<StockLineDraft> projectDraftLines;
  final bool loadingProjectComponents;
  final bool savingProjectComponents;
  final bool projectComponentsDirty;
  final bool savingProjectDescription;
  final bool projectDescriptionDirty;
  final bool uploadingProjectImage;
  final bool showAllProjectComponents;
  final bool canCaptureProjectImage;
  final VoidCallback onCreateProject;
  final ValueChanged<Map<String, dynamic>> onOpenProject;
  final ValueChanged<Map<String, dynamic>> onEditProject;
  final ValueChanged<Map<String, dynamic>> onDeleteProject;
  final ValueChanged<Map<String, dynamic>> onExportProjectPdf;
  final ValueChanged<Map<String, dynamic>> onToggleProjectListComponents;
  final ValueChanged<String> onLoadProjectListComponents;
  final VoidCallback onCloseProject;
  final ValueChanged<bool> onUploadProjectImage;
  final VoidCallback onSaveProjectDescription;
  final VoidCallback onLoadProjectComponents;
  final VoidCallback onSaveProjectComponents;
  final ValueChanged<Map<String, dynamic>> onAddProjectDraftLine;
  final ValueChanged<StockLineDraft> onRemoveProjectDraftLine;
  final void Function(StockLineDraft line, int delta)
  onAdjustProjectDraftQuantity;
  final ValueChanged<bool> onProjectComponentsDirtyChanged;
  final ValueChanged<bool> onProjectDescriptionDirtyChanged;
  final ValueChanged<bool> onShowAllProjectComponentsChanged;
  final ValueChanged<TextEditingController?> onProjectSearchControllerChanged;
  final Widget Function(Map<String, dynamic> component, {required double size})
  buildComponentThumbnail;
  final Widget Function(
    String path, {
    Key? key,
    BoxFit fit,
    required Widget errorChild,
  })
  buildInventoryImage;
  final Map<String, dynamic> Function(Map<String, dynamic> projectLine)
  projectLineAsComponent;

  @override
  Widget build(BuildContext context) {
    final project = activeProject;
    if (project != null) {
      return ProjectDetailsView(
        project: project,
        error: error,
        activeProjectDescriptionController: activeProjectDescriptionController,
        projectDraftLines: projectDraftLines,
        components: components,
        loadingProjectComponents: loadingProjectComponents,
        savingProjectComponents: savingProjectComponents,
        projectComponentsDirty: projectComponentsDirty,
        savingProjectDescription: savingProjectDescription,
        projectDescriptionDirty: projectDescriptionDirty,
        uploadingProjectImage: uploadingProjectImage,
        showAllProjectComponents: showAllProjectComponents,
        canCaptureProjectImage: canCaptureProjectImage,
        api: api,
        onCloseProject: onCloseProject,
        onEditProject: onEditProject,
        onDeleteProject: onDeleteProject,
        onUploadProjectImage: onUploadProjectImage,
        onSaveProjectDescription: onSaveProjectDescription,
        onLoadProjectComponents: onLoadProjectComponents,
        onSaveProjectComponents: onSaveProjectComponents,
        onAddProjectDraftLine: onAddProjectDraftLine,
        onRemoveProjectDraftLine: onRemoveProjectDraftLine,
        onAdjustProjectDraftQuantity: onAdjustProjectDraftQuantity,
        onProjectComponentsDirtyChanged: onProjectComponentsDirtyChanged,
        onProjectDescriptionDirtyChanged: onProjectDescriptionDirtyChanged,
        onShowAllProjectComponentsChanged: onShowAllProjectComponentsChanged,
        onProjectSearchControllerChanged: onProjectSearchControllerChanged,
        buildComponentThumbnail: buildComponentThumbnail,
        buildInventoryImage: buildInventoryImage,
      );
    }

    return Column(
      children: [
        if (error != null) ErrorBanner(errorMessage: error!),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: projectNameController,
                decoration: const InputDecoration(
                  labelText: 'Project or YouTube video',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onCreateProject,
              icon: const Icon(Icons.add),
              tooltip: 'Add project',
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: newProjectDescriptionController,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Project description (optional)',
            hintText: 'Purpose, scope, build notes, or other project details',
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: projects.isEmpty
              ? const Center(
                  child: Text(
                    'No projects yet. Create one above to start consuming components.',
                    textAlign: TextAlign.center,
                  ),
                )
              : projectViewMode == 'Thumbnails'
              ? _ProjectThumbnailView(
                  projects: projects,
                  exportingProjectId: exportingProjectId,
                  expandedProjectIds: expandedProjectIds,
                  projectListComponents: projectListComponents,
                  projectListErrors: projectListErrors,
                  loadingProjectListIds: loadingProjectListIds,
                  onOpenProject: onOpenProject,
                  onEditProject: onEditProject,
                  onDeleteProject: onDeleteProject,
                  onExportProjectPdf: onExportProjectPdf,
                  onToggleProjectListComponents: onToggleProjectListComponents,
                  onLoadProjectListComponents: onLoadProjectListComponents,
                  buildProjectImageBanner: _buildProjectImageBanner,
                  buildComponentThumbnail: buildComponentThumbnail,
                  projectLineAsComponent: projectLineAsComponent,
                )
              : ListView(
                  children: projects.map((item) {
                    final project = Map<String, dynamic>.from(item as Map);
                    final description =
                        (project['description'] as String? ?? '').trim();
                    final projectId = project['id'] as String;
                    final expanded = expandedProjectIds.contains(projectId);
                    final exporting = exportingProjectId == projectId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
                          ListTile(
                            leading: _buildProjectImageTile(project, size: 48),
                            title: Text(project['name'] as String),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${project['project_type']} • ${project['status']}',
                                ),
                                if (description.isNotEmpty)
                                  Text(
                                    description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: ValueKey(
                                    'expand-project-components-$projectId',
                                  ),
                                  onPressed: () =>
                                      onToggleProjectListComponents(project),
                                  icon: Icon(
                                    expanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                  ),
                                  tooltip: expanded
                                      ? 'Hide project components'
                                      : 'View project components',
                                ),
                                IconButton(
                                  key: ValueKey(
                                    'export-project-pdf-${project['id']}',
                                  ),
                                  onPressed: exporting
                                      ? null
                                      : () => onExportProjectPdf(project),
                                  icon: exporting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.picture_as_pdf),
                                  tooltip: 'Export project as PDF',
                                ),
                                IconButton(
                                  onPressed: () => onEditProject(project),
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit project',
                                ),
                                IconButton(
                                  onPressed: () => onDeleteProject(project),
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Remove project',
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () => onOpenProject(project),
                          ),
                          if (expanded)
                            _ProjectListComponentsPanel(
                              projectId: projectId,
                              components: projectListComponents[projectId],
                              error: projectListErrors[projectId],
                              loading: loadingProjectListIds.contains(
                                projectId,
                              ),
                              onRetry: () =>
                                  onLoadProjectListComponents(projectId),
                              buildComponentThumbnail: buildComponentThumbnail,
                              projectLineAsComponent: projectLineAsComponent,
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildProjectImageTile(
    Map<String, dynamic> project, {
    required double size,
  }) {
    final path = project['image_url'] as String?;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: path == null
            ? Builder(
                builder: (context) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.video_library),
                ),
              )
            : Builder(
                builder: (context) => buildInventoryImage(
                  path,
                  key: ValueKey('project-image-${project['id']}'),
                  fit: BoxFit.cover,
                  errorChild: ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProjectImageBanner(
    Map<String, dynamic> project, {
    required double height,
  }) {
    final path = project['image_url'] as String?;
    if (path == null) {
      return Builder(
        builder: (context) => SizedBox(
          height: height,
          width: double.infinity,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.video_library, size: 48)),
          ),
        ),
      );
    }
    return Builder(
      builder: (context) => SizedBox(
        height: height,
        width: double.infinity,
        child: buildInventoryImage(
          path,
          key: ValueKey('project-banner-${project['id']}'),
          fit: BoxFit.cover,
          errorChild: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Icon(Icons.broken_image_outlined, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectThumbnailView extends StatelessWidget {
  const _ProjectThumbnailView({
    required this.projects,
    required this.exportingProjectId,
    required this.expandedProjectIds,
    required this.projectListComponents,
    required this.projectListErrors,
    required this.loadingProjectListIds,
    required this.onOpenProject,
    required this.onEditProject,
    required this.onDeleteProject,
    required this.onExportProjectPdf,
    required this.onToggleProjectListComponents,
    required this.onLoadProjectListComponents,
    required this.buildProjectImageBanner,
    required this.buildComponentThumbnail,
    required this.projectLineAsComponent,
  });

  final List<dynamic> projects;
  final String? exportingProjectId;
  final Set<String> expandedProjectIds;
  final Map<String, List<Map<String, dynamic>>> projectListComponents;
  final Map<String, String> projectListErrors;
  final Set<String> loadingProjectListIds;
  final ValueChanged<Map<String, dynamic>> onOpenProject;
  final ValueChanged<Map<String, dynamic>> onEditProject;
  final ValueChanged<Map<String, dynamic>> onDeleteProject;
  final ValueChanged<Map<String, dynamic>> onExportProjectPdf;
  final ValueChanged<Map<String, dynamic>> onToggleProjectListComponents;
  final ValueChanged<String> onLoadProjectListComponents;
  final Widget Function(Map<String, dynamic> project, {required double height})
  buildProjectImageBanner;
  final Widget Function(Map<String, dynamic> component, {required double size})
  buildComponentThumbnail;
  final Map<String, dynamic> Function(Map<String, dynamic> projectLine)
  projectLineAsComponent;

  @override
  Widget build(BuildContext context) {
    final projectMaps = projects
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        const spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return SingleChildScrollView(
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: projectMaps
                .map(
                  (project) => _ProjectThumbnailCard(
                    project: project,
                    width: cardWidth,
                    expanded: expandedProjectIds.contains(
                      project['id'] as String,
                    ),
                    exporting: exportingProjectId == project['id'],
                    components: projectListComponents[project['id'] as String],
                    error: projectListErrors[project['id'] as String],
                    loading: loadingProjectListIds.contains(
                      project['id'] as String,
                    ),
                    onOpenProject: onOpenProject,
                    onEditProject: onEditProject,
                    onDeleteProject: onDeleteProject,
                    onExportProjectPdf: onExportProjectPdf,
                    onToggleProjectListComponents:
                        onToggleProjectListComponents,
                    onRetry: () =>
                        onLoadProjectListComponents(project['id'] as String),
                    buildProjectImageBanner: buildProjectImageBanner,
                    buildComponentThumbnail: buildComponentThumbnail,
                    projectLineAsComponent: projectLineAsComponent,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _ProjectThumbnailCard extends StatelessWidget {
  const _ProjectThumbnailCard({
    required this.project,
    required this.width,
    required this.expanded,
    required this.exporting,
    required this.components,
    required this.error,
    required this.loading,
    required this.onOpenProject,
    required this.onEditProject,
    required this.onDeleteProject,
    required this.onExportProjectPdf,
    required this.onToggleProjectListComponents,
    required this.onRetry,
    required this.buildProjectImageBanner,
    required this.buildComponentThumbnail,
    required this.projectLineAsComponent,
  });

  final Map<String, dynamic> project;
  final double width;
  final bool expanded;
  final bool exporting;
  final List<Map<String, dynamic>>? components;
  final String? error;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onOpenProject;
  final ValueChanged<Map<String, dynamic>> onEditProject;
  final ValueChanged<Map<String, dynamic>> onDeleteProject;
  final ValueChanged<Map<String, dynamic>> onExportProjectPdf;
  final ValueChanged<Map<String, dynamic>> onToggleProjectListComponents;
  final VoidCallback onRetry;
  final Widget Function(Map<String, dynamic> project, {required double height})
  buildProjectImageBanner;
  final Widget Function(Map<String, dynamic> component, {required double size})
  buildComponentThumbnail;
  final Map<String, dynamic> Function(Map<String, dynamic> projectLine)
  projectLineAsComponent;

  @override
  Widget build(BuildContext context) {
    final projectId = project['id'] as String;
    final description = (project['description'] as String? ?? '').trim();
    return SizedBox(
      key: ValueKey('project-thumbnail-$projectId'),
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => onOpenProject(project),
              child: buildProjectImageBanner(project, height: 170),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project['name'] as String,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${project['project_type']} • ${project['status']}${project['total_cost'] != null ? ' • Cost: \$${project['total_cost']}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => onToggleProjectListComponents(project),
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    tooltip: expanded
                        ? 'Hide project components'
                        : 'View project components',
                  ),
                  IconButton(
                    onPressed: exporting
                        ? null
                        : () => onExportProjectPdf(project),
                    icon: exporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    tooltip: 'Export project as PDF',
                  ),
                  IconButton(
                    onPressed: () => onEditProject(project),
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit project',
                  ),
                  IconButton(
                    onPressed: () => onDeleteProject(project),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove project',
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => onOpenProject(project),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open'),
                  ),
                ],
              ),
            ),
            if (expanded)
              _ProjectListComponentsPanel(
                projectId: projectId,
                components: components,
                error: error,
                loading: loading,
                onRetry: onRetry,
                buildComponentThumbnail: buildComponentThumbnail,
                projectLineAsComponent: projectLineAsComponent,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProjectListComponentsPanel extends StatelessWidget {
  const _ProjectListComponentsPanel({
    required this.projectId,
    required this.components,
    required this.error,
    required this.loading,
    required this.onRetry,
    required this.buildComponentThumbnail,
    required this.projectLineAsComponent,
  });

  final String projectId;
  final List<Map<String, dynamic>>? components;
  final String? error;
  final bool loading;
  final VoidCallback onRetry;
  final Widget Function(Map<String, dynamic> component, {required double size})
  buildComponentThumbnail;
  final Map<String, dynamic> Function(Map<String, dynamic> projectLine)
  projectLineAsComponent;

  @override
  Widget build(BuildContext context) {
    final componentLines = components;
    if (loading && componentLines == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LinearProgressIndicator(),
      );
    }
    if (error != null && componentLines == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(child: Text(error!)),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (componentLines == null) return const SizedBox.shrink();

    return Container(
      key: ValueKey('project-components-$projectId'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: componentLines.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No components have been added to this project.'),
            )
          : Column(
              children: componentLines.map((line) {
                final component = projectLineAsComponent(line);
                final details = [
                  line['package_type'],
                  line['manufacturer'],
                  line['location_name'],
                ].whereType<String>().where((value) => value.trim().isNotEmpty);
                final notes = (line['notes'] as String? ?? '').trim();
                return ListTile(
                  key: ValueKey(
                    'project-list-line-$projectId-${line['component_id']}',
                  ),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: buildComponentThumbnail(component, size: 42),
                  title: Text(
                    '${line['inventory_code']} • ${line['component_name']}',
                  ),
                  subtitle: Text(
                    [
                      if (component['supplier_name'] != null &&
                          '${component['supplier_name']}'.isNotEmpty)
                        'Supplier: ${component['supplier_name']}',
                      if (details.isNotEmpty) details.join(' • '),
                      if (notes.isNotEmpty) 'Note: $notes',
                    ].join('\n'),
                  ),
                  trailing: Text(
                    '${formatComponentQuantity(line['quantity'])} ${line['unit']}',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class ProjectDetailsView extends StatelessWidget {
  const ProjectDetailsView({
    super.key,
    required this.project,
    required this.error,
    required this.activeProjectDescriptionController,
    required this.projectDraftLines,
    required this.components,
    required this.loadingProjectComponents,
    required this.savingProjectComponents,
    required this.projectComponentsDirty,
    required this.savingProjectDescription,
    required this.projectDescriptionDirty,
    required this.uploadingProjectImage,
    required this.showAllProjectComponents,
    required this.canCaptureProjectImage,
    required this.api,
    required this.onCloseProject,
    required this.onEditProject,
    required this.onDeleteProject,
    required this.onUploadProjectImage,
    required this.onSaveProjectDescription,
    required this.onLoadProjectComponents,
    required this.onSaveProjectComponents,
    required this.onAddProjectDraftLine,
    required this.onRemoveProjectDraftLine,
    required this.onAdjustProjectDraftQuantity,
    required this.onProjectComponentsDirtyChanged,
    required this.onProjectDescriptionDirtyChanged,
    required this.onShowAllProjectComponentsChanged,
    required this.onProjectSearchControllerChanged,
    required this.buildComponentThumbnail,
    required this.buildInventoryImage,
  });

  final Map<String, dynamic> project;
  final String? error;
  final TextEditingController activeProjectDescriptionController;
  final List<StockLineDraft> projectDraftLines;
  final List<dynamic> components;
  final bool loadingProjectComponents;
  final bool savingProjectComponents;
  final bool projectComponentsDirty;
  final bool savingProjectDescription;
  final bool projectDescriptionDirty;
  final bool uploadingProjectImage;
  final bool showAllProjectComponents;
  final bool canCaptureProjectImage;
  final ApiClient api;
  final VoidCallback onCloseProject;
  final ValueChanged<Map<String, dynamic>> onEditProject;
  final ValueChanged<Map<String, dynamic>> onDeleteProject;
  final ValueChanged<bool> onUploadProjectImage;
  final VoidCallback onSaveProjectDescription;
  final VoidCallback onLoadProjectComponents;
  final VoidCallback onSaveProjectComponents;
  final ValueChanged<Map<String, dynamic>> onAddProjectDraftLine;
  final ValueChanged<StockLineDraft> onRemoveProjectDraftLine;
  final void Function(StockLineDraft line, int delta)
  onAdjustProjectDraftQuantity;
  final ValueChanged<bool> onProjectComponentsDirtyChanged;
  final ValueChanged<bool> onProjectDescriptionDirtyChanged;
  final ValueChanged<bool> onShowAllProjectComponentsChanged;
  final ValueChanged<TextEditingController?> onProjectSearchControllerChanged;
  final Widget Function(Map<String, dynamic> component, {required double size})
  buildComponentThumbnail;
  final Widget Function(
    String path, {
    Key? key,
    BoxFit fit,
    required Widget errorChild,
  })
  buildInventoryImage;

  @override
  Widget build(BuildContext context) {
    final hasProjectImage = project['image_url'] != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ErrorBanner(errorMessage: error!),
        Row(
          children: [
            IconButton(
              onPressed: onCloseProject,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to projects',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project['name'] as String,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${project['project_type']} • ${project['status']}${project['total_cost'] != null ? ' • Cost: \$${project['total_cost']}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              avatar: const Icon(Icons.memory, size: 18),
              label: Text(
                '${projectDraftLines.length} component'
                '${projectDraftLines.length == 1 ? '' : 's'}',
              ),
            ),
            IconButton(
              onPressed: () => onEditProject(project),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit project',
            ),
            IconButton(
              onPressed: () => onDeleteProject(project),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove project',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasProjectImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _projectImageBanner(context, project, height: 190),
                  ),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      key: const ValueKey('upload-project-image'),
                      onPressed: uploadingProjectImage
                          ? null
                          : () => onUploadProjectImage(false),
                      icon: uploadingProjectImage
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate),
                      label: Text(
                        hasProjectImage
                            ? 'Replace project image'
                            : 'Add project image',
                      ),
                    ),
                    if (canCaptureProjectImage)
                      OutlinedButton.icon(
                        onPressed: uploadingProjectImage
                            ? null
                            : () => onUploadProjectImage(true),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take project photo'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('project-description-field'),
                  controller: activeProjectDescriptionController,
                  minLines: 2,
                  maxLines: 5,
                  onChanged: (_) {
                    if (!projectDescriptionDirty) {
                      onProjectDescriptionDirtyChanged(true);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Project description',
                    hintText:
                        'Save the purpose, scope, progress, or other useful notes about this project',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('save-project-description'),
                    onPressed:
                        !projectDescriptionDirty || savingProjectDescription
                        ? null
                        : onSaveProjectDescription,
                    icon: savingProjectDescription
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save description'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (loadingProjectComponents)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else ...[
          _ProjectComponentPicker(
            api: api,
            components: components,
            projectDraftLines: projectDraftLines,
            showAllProjectComponents: showAllProjectComponents,
            onAddProjectDraftLine: onAddProjectDraftLine,
            onShowAllProjectComponentsChanged:
                onShowAllProjectComponentsChanged,
            onProjectSearchControllerChanged: onProjectSearchControllerChanged,
            buildComponentThumbnail: buildComponentThumbnail,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: projectDraftLines.isEmpty
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: const Text(
                        'No components selected. Search above and select a component to add it instantly.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    children: projectDraftLines
                        .map(
                          (line) => _ProjectDraftLineRow(
                            line: line,
                            onRemoveProjectDraftLine: onRemoveProjectDraftLine,
                            onAdjustProjectDraftQuantity:
                                onAdjustProjectDraftQuantity,
                            onProjectComponentsDirtyChanged:
                                onProjectComponentsDirtyChanged,
                            projectComponentsDirty: projectComponentsDirty,
                            buildComponentThumbnail: buildComponentThumbnail,
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  projectComponentsDirty
                      ? 'You have unsaved project changes.'
                      : 'Project components are saved.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              OutlinedButton(
                onPressed: !projectComponentsDirty || savingProjectComponents
                    ? null
                    : onLoadProjectComponents,
                child: const Text('Discard'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: !projectComponentsDirty || savingProjectComponents
                    ? null
                    : onSaveProjectComponents,
                icon: savingProjectComponents
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save all'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _projectImageBanner(
    BuildContext context,
    Map<String, dynamic> project, {
    required double height,
  }) {
    final path = project['image_url'] as String?;
    if (path == null) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.video_library, size: 48)),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: buildInventoryImage(
        path,
        key: ValueKey('project-banner-${project['id']}'),
        fit: BoxFit.cover,
        errorChild: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 48),
          ),
        ),
      ),
    );
  }
}

class _ProjectComponentPicker extends StatelessWidget {
  const _ProjectComponentPicker({
    required this.api,
    required this.components,
    required this.projectDraftLines,
    required this.showAllProjectComponents,
    required this.onAddProjectDraftLine,
    required this.onShowAllProjectComponentsChanged,
    required this.onProjectSearchControllerChanged,
    required this.buildComponentThumbnail,
  });

  final ApiClient api;
  final List<dynamic> components;
  final List<StockLineDraft> projectDraftLines;
  final bool showAllProjectComponents;
  final ValueChanged<Map<String, dynamic>> onAddProjectDraftLine;
  final ValueChanged<bool> onShowAllProjectComponentsChanged;
  final ValueChanged<TextEditingController?> onProjectSearchControllerChanged;
  final Widget Function(Map<String, dynamic> component, {required double size})
  buildComponentThumbnail;

  @override
  Widget build(BuildContext context) {
    final localComponents = components
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    Iterable<Map<String, dynamic>> excludeSelected(
      Iterable<Map<String, dynamic>> options,
    ) {
      final selectedIds = projectDraftLines
          .map((line) => line.component['id'] as String)
          .toSet();
      return options.where(
        (component) => !selectedIds.contains(component['id'] as String),
      );
    }

    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: _stockComponentLabel,
      optionsBuilder: (value) async {
        final query = value.text.trim();
        if (query.isEmpty) {
          return showAllProjectComponents
              ? excludeSelected(localComponents).take(30)
              : const Iterable<Map<String, dynamic>>.empty();
        }
        try {
          final results = await api.components(query: query);
          return excludeSelected(
            results.map((item) => Map<String, dynamic>.from(item as Map)),
          ).take(30);
        } catch (_) {
          final normalizedQuery = query.toLowerCase();
          return excludeSelected(localComponents)
              .where((component) {
                final haystack = [
                  component['inventory_code'],
                  component['name'],
                  component['manufacturer'],
                  component['package_type'],
                  component['location_name'],
                  component['description'],
                ].whereType<Object>().join(' ').toLowerCase();
                return haystack.contains(normalizedQuery);
              })
              .take(30);
        }
      },
      onSelected: (component) {
        onAddProjectDraftLine(component);
        onShowAllProjectComponentsChanged(false);
        onProjectSearchControllerChanged(null);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        onProjectSearchControllerChanged(controller);
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            prefixIcon: IconButton(
              onPressed: () {
                onShowAllProjectComponentsChanged(true);
                focusNode.requestFocus();
                if (controller.text.trim().isEmpty) {
                  controller.text = ' ';
                  controller.selection = TextSelection.collapsed(
                    offset: controller.text.length,
                  );
                }
              },
              icon: const Icon(Icons.search),
              tooltip: 'Show inventory components',
            ),
            labelText: 'Search component to add to this project',
            helperText:
                'Select a result to add it instantly, then adjust quantities below.',
          ),
          onChanged: (value) {
            if (value.trim().isNotEmpty && showAllProjectComponents) {
              onShowAllProjectComponentsChanged(false);
            }
          },
          onSubmitted: (_) {
            onSubmitted();
            controller.clear();
            onShowAllProjectComponentsChanged(false);
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 620),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final component = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: buildComponentThumbnail(component, size: 40),
                    title: Text(_stockComponentLabel(component)),
                    subtitle: Text(_stockComponentDetail(component)),
                    onTap: () => onSelected(component),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProjectDraftLineRow extends StatelessWidget {
  const _ProjectDraftLineRow({
    required this.line,
    required this.onRemoveProjectDraftLine,
    required this.onAdjustProjectDraftQuantity,
    required this.onProjectComponentsDirtyChanged,
    required this.projectComponentsDirty,
    required this.buildComponentThumbnail,
  });

  final StockLineDraft line;
  final ValueChanged<StockLineDraft> onRemoveProjectDraftLine;
  final void Function(StockLineDraft line, int delta)
  onAdjustProjectDraftQuantity;
  final ValueChanged<bool> onProjectComponentsDirtyChanged;
  final bool projectComponentsDirty;
  final Widget Function(Map<String, dynamic> component, {required double size})
  buildComponentThumbnail;

  @override
  Widget build(BuildContext context) {
    final component = line.component;
    final unit = component['unit'] as String? ?? 'Pieces';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final identity = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildComponentThumbnail(component, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stockComponentLabel(component),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _stockComponentDetail(component),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            );
            final controls = Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => onAdjustProjectDraftQuantity(line, -1),
                  icon: const Icon(Icons.remove),
                  tooltip: 'Decrease quantity',
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: compact ? 92 : 120,
                  child: TextField(
                    controller: line.quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      suffixText: unit,
                    ),
                    onChanged: (_) {
                      if (!projectComponentsDirty) {
                        onProjectComponentsDirtyChanged(true);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => onAdjustProjectDraftQuantity(line, 1),
                  icon: const Icon(Icons.add),
                  tooltip: 'Increase quantity',
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => onRemoveProjectDraftLine(line),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove from project draft',
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: controls),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                controls,
              ],
            );
          },
        ),
      ),
    );
  }
}

String _stockComponentLabel(Map<String, dynamic> component) {
  return component['name'] as String? ?? 'Component';
}

String _stockComponentDetail(Map<String, dynamic> component) {
  return [
    if ((component['package_type'] as String?)?.isNotEmpty == true)
      component['package_type'],
    if ((component['manufacturer'] as String?)?.isNotEmpty == true)
      component['manufacturer'],
    if ((component['location_name'] as String?)?.isNotEmpty == true)
      component['location_name'],
    '${component['current_quantity']} ${component['unit']} available',
  ].join(' • ');
}
