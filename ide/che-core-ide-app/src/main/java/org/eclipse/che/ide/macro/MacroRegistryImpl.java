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
package org.eclipse.che.ide.macro;

import com.google.inject.Inject;

import org.eclipse.che.ide.api.macro.Macro;
import org.eclipse.che.ide.api.macro.MacroRegistry;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Implementation for {@link MacroRegistry}.
 *
 * @author Artem Zatsarynnyi
 */
public class MacroRegistryImpl implements MacroRegistry {

    private final Map<String, Macro> macros;

    public MacroRegistryImpl() {
        this.macros = new HashMap<>();
    }

    @Inject(optional = true)
    public void register(Set<Macro> macros) {
        for (Macro macro : macros) {
            final String name = macro.getName();
            if (!this.macros.containsKey(name)) {
                this.macros.put(name, macro);
            }
        }
    }

    @Override
    public void unregister(Macro macro) {
        macros.remove(macro.getName());
    }

    @Override
    public Macro getMacro(String name) {
        return macros.get(name);
    }

    @Override
    public List<Macro> getMacros() {
        return new ArrayList<>(macros.values());
    }

    @Override
    public Set<String> getNames() {
        return macros.keySet();
    }
}
