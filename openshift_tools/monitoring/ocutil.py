#!/usr/bin/env python
# vim: expandtab:tabstop=4:shiftwidth=4
'''
  Interface to OpenShift oc command
'''
#
#   Copyright 2015 Red Hat Inc.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# Disabling invalid-name because pylint doesn't like the naming conention we have.
# pylint: disable=invalid-name
# pylint: disable=too-few-public-methods

import os
import shlex
import atexit
import shutil
import string
import random
import yaml
import subprocess

# pylint: disable=bare-except
def cleanup_file(inc_file):
    ''' clean up '''
    try:
        os.unlink(inc_file)
    except:
        pass

class OCUtil(object):
    ''' Wrapper for interfacing with OpenShift 'oc' utility '''

    def __init__(self, namespace='default', config_file='/tmp/admin.kubeconfig', verbose=False):
        '''
        Take initial values for running 'oc'
        Ensure to set non-default namespace if that is what is desired
        '''
        self.namespace = namespace
        self.config_file = config_file
        self.verbose = verbose
        self.copy_kubeconfig()

    def copy_kubeconfig(self):
        ''' make a copy of the kubeconfig '''

        file_name = os.path.join('/tmp',
                                 ''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(7)))
        shutil.copy(self.config_file, file_name)
        atexit.register(cleanup_file, file_name)

        self.config_file = file_name

    def _run_cmd(self, cmd):
        ''' Actually execute the command '''

        cmd = 'oc --config ' + self.config_file + ' -n ' + self.namespace + ' ' + cmd
        cmd = shlex.split(cmd)
        if self.verbose:
            print "Running command: {}".format(str(cmd))

        results = subprocess.check_output(cmd)

        try:
            return yaml.safe_load(results)
        except:
            return results

    def get_secrets(self, name):
        ''' Get secrets from object 'name' '''


        secrets_cmd = "get secrets {} -o yaml".format(name)
        secrets_yaml = self._run_cmd(secrets_cmd)

        return secrets_yaml

    def get_endpoint(self, name):
        ''' Get endpoint details '''

        endpoint_cmd = "get endpoints {} -o yaml".format(name)
        endpoint_yaml = self._run_cmd(endpoint_cmd)

        return endpoint_yaml

    def get_service(self, name):
        ''' Get service details '''

        service_cmd = "get service {} -o yaml".format(name)
        service_yaml = self._run_cmd(service_cmd)

        return service_yaml

    def get_dc(self, name):
        ''' Get deployment config details '''

        dc_cmd = "get dc {} -o yaml".format(name)
        dc_yaml = self._run_cmd(dc_cmd)

        return dc_yaml

    def get_route(self, name):
        ''' Get routes details '''

        route_cmd = "get route {} -o yaml".format(name)
        route_yaml = self._run_cmd(route_cmd)

        return route_yaml

    def get_pods(self):
        ''' Get all the pods in the namespace '''

        pods_cmd = "get pods -o yaml"
        pods_yaml = self._run_cmd(pods_cmd)

        return pods_yaml

    def get_projects(self):
        ''' Get all projects in the cluster '''

        nodes_cmd = "oc get projects -o yaml"
        nodes_yaml = self._run_cmd(nodes_cmd)

        return nodes_yaml

    def get_nodes(self):
        ''' Get all the nodes in the cluster '''

        nodes_cmd = "get nodes -o yaml"
        nodes_yaml = self._run_cmd(nodes_cmd)

        return nodes_yaml

    def get_log(self, name):
        ''' Gets the log for the specified container '''

        log_cmd = "logs {}".format(name)
        log_results = self._run_cmd(log_cmd)

        return log_results

    def run_user_cmd(self, command):
        ''' Runs a custom user command '''

        user_results = self._run_cmd(command)
        return user_results
