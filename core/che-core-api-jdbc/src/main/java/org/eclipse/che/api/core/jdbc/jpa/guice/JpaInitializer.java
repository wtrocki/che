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
package org.eclipse.che.api.core.jdbc.jpa.guice;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import com.google.inject.persist.PersistService;

import org.eclipse.che.api.core.jdbc.schema.SchemaInitializationException;
import org.eclipse.che.api.core.jdbc.schema.SchemaInitializer;

/**
 * Should be bound as eager singleton.
 * See <a href="https://github.com/google/guice/wiki/JPA">doc</a>
 *
 * @author Yevhenii Voevodin
 * @author Anton Korneta
 */
@Singleton
public class JpaInitializer {

    @Inject
    public void init(PersistService persistService, SchemaInitializer schemaInitializer) {
        try {
            schemaInitializer.initialize();
        } catch (SchemaInitializationException x) {
            throw new RuntimeException(x.getMessage(), x);
        }
        persistService.start();
    }
}
