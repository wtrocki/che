/*******************************************************************************
 * Copyright (c) 2012-2016 Codenvy, S.A.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   Codenvy, S.A. - initial API and implementation
 *******************************************************************************/
package org.eclipse.che.plugin.nodejs.generator;

import com.google.inject.Inject;

import org.eclipse.che.api.core.ConflictException;
import org.eclipse.che.api.core.ForbiddenException;
import org.eclipse.che.api.core.ServerException;
import org.eclipse.che.api.project.server.FolderEntry;
import org.eclipse.che.api.project.server.handlers.CreateProjectHandler;
import org.eclipse.che.api.project.server.type.AttributeValue;
import org.eclipse.che.api.vfs.Path;
import org.eclipse.che.api.vfs.VirtualFileSystem;
import org.eclipse.che.api.vfs.VirtualFileSystemProvider;
import org.eclipse.che.plugin.nodejs.shared.Constants;

import java.util.Map;

/**
 * Generates new project which contains file with default content.
 *
 * @author Dmitry Shnurenko
 */
public class NodeJsProjectGenerator implements CreateProjectHandler {

    @Inject
    private VirtualFileSystemProvider virtualFileSystemProvider;

    private static final String FILE_NAME = "hello.js";

    @Override
    public void onCreateProject(Path projectPath,
                                Map<String, AttributeValue> attributes,
                                Map<String, String> options) throws ForbiddenException, ConflictException, ServerException {

        VirtualFileSystem vfs = virtualFileSystemProvider.getVirtualFileSystem();
        FolderEntry baseFolder  = new FolderEntry(vfs.getRoot().createFolder(projectPath.toString()));
        baseFolder.createFile(FILE_NAME, getClass().getClassLoader().getResourceAsStream("files/default_node_content"));
    }

    @Override
    public String getProjectType() {
        return Constants.NODE_JS_PROJECT_TYPE_ID;
    }
}

