# -------------------------------------------------------------------------- #
# Copyright 2002-2023, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

require 'opennebula'

class OpenNebulaVMCollector

    LABELS = [:one_vm_id]

    # --------------------------------------------------------------------------
    # VM metrics
    # --------------------------------------------------------------------------
    #   - opennebula_vm_total
    #   - opennebula_vm_state
    #   - opennebula_vm_lcm_state
    #   - opennebula_vm_mem_total_bytes
    #   - opennebula_vm_cpu_ratio
    #   - opennebula_vm_cpu_vcpus
    #   - opennebula_vm_disks
    #   - opennebula_vm_disk_size_bytes
    #   - opennebula_vm_nics
    #   - opennebula_vm_ut_flavours
    #   - opennebula_vm_power_consumption_uW
    # --------------------------------------------------------------------------
    VM_METRICS = {
        'vm_total' => {
            :type   => :gauge,
            :docstr => 'Total number of VMs defined in OpenNebula',
            :labels => {}
        },
        'vm_host_id' => {
            :type   => :gauge,
            :docstr => 'Host ID where the VM is allocated',
            :value  => lambda {|v|
                hid = v['HISTORY_RECORDS/HISTORY[last()]/HID']

                if !hid || hid.empty?
                    -1
                else
                    Integer(hid)
                end
            },
            :labels => LABELS
        },
        'vm_state' => {
            :type   => :gauge,
            :docstr => 'VM state 0:init 1:pending 2:hold 3:active ' \
                       '4:stopped 5:suspended 6:done 8:poweroff ' \
                       '9:undeployed 10:clonning',
            :value  => ->(v) { Integer(v['STATE']) },
            :labels => LABELS
        },
        'vm_lcm_state' => {
            :type   => :gauge,
            :docstr => 'VM LCM state, only relevant for state 3 (active)',
            :value  => ->(v) { Integer(v['LCM_STATE']) },
            :labels => LABELS
        },
        'vm_mem_total_bytes' => {
            :type   => :gauge,
            :docstr => 'Total memory capacity',
            :value  => ->(v) { Integer(v['TEMPLATE/MEMORY']) * 1024 },
            :labels => LABELS
        },
        'vm_cpu_ratio' => {
            :type   => :gauge,
            :docstr => 'Total CPU capacity requested by the VM',
            :value  => ->(v) { Float(v['TEMPLATE/CPU']) },
            :labels => LABELS
        },
        'vm_cpu_vcpus' => {
            :type   => :gauge,
            :docstr => 'Total number of virtual CPUs',
            :value  => lambda {|v|
                vcpus = v['TEMPLATE/VCPU']

                if !vcpus || vcpus.empty?
                    1
                else
                    Integer(vcpus)
                end
            },
            :labels => LABELS
        },
        'vm_ut_flavours' => {
            :type   => :gauge,
            :docstr => 'Flavours used to create the Serverless Runtime in the Provisioning Engine',
            :value  => lambda {|v|
                flavours = v['USER_TEMPLATE/FLAVOURS']

                if !flavours || flavours.empty?
                    -1
                else
                    Integer(flavours)
                end
            },
            :labels => LABELS
        },
        'vm_power_consumption_uW' => {
            :type   => :gauge,
            :docstr => 'Scaphandre power usage by the VM in uW',
            :value  => lambda {|v|
                uri = URI("http://#{v['HISTORY_RECORDS/HISTORY[last()]/HOSTNAME']}:8080/metrics")
                res = Net::HTTP.get_response(uri)
                power = res.body.split("\n").grep(/one-#{v['ID']},/)[0] if res.is_a?(Net::HTTPOK)
                if power
                    power.split.last.to_i
                else
                    0
                end
            },
            :labels => LABELS
        }

    }

    DISK_METRICS = {
        'vm_disks' => {
            :type   => :gauge,
            :docstr => 'Total number of disks',
            :labels => LABELS
        },
        'vm_disk_size_bytes' => {
            :type   => :gauge,
            :docstr => 'Size of the VM disk',
            :value  => lambda {|i, v|
                           Integer(v["TEMPLATE/DISK [ DISK_ID = #{i} ]/SIZE"]) * 1024 * 1024
                       },
            :labels => LABELS + [:disk_id]
        }
    }

    NIC_METRICS = {
        'vm_nics' => {
            :type   => :gauge,
            :docstr => 'Total number of network interfaces',
            :labels => LABELS
        }
    }

    def initialize(registry, client, namespace)
        @client  = client
        @metrics = {}

        [VM_METRICS, DISK_METRICS, NIC_METRICS].each do |m|
            m.each do |name, conf|
                @metrics[name] = registry.method(conf[:type]).call(
                    "#{namespace}_#{name}".to_sym,
                    :docstring => conf[:docstr],
                    :labels    => conf[:labels]
                )
            end
        end
    end

    def collect
        vm_pool = OpenNebula::VirtualMachinePool.new(@client)
        rc      = vm_pool.info_all

        raise rc.message if OpenNebula.is_error?(rc)

        vms = vm_pool.retrieve_xmlelements('/VM_POOL/VM')

        @metrics['vm_total'].set(vms.length)

        vms.each do |vm|
            labels = { :one_vm_id => Integer(vm['ID']) }

            VM_METRICS.each do |name, conf|
                next unless conf[:value]

                metric = @metrics[name]

                # TODO: vm from vm_pool doesn't load USER_TEMPLATE so it needs to be loaded individually
                vm_full = OpenNebula::VirtualMachine.new_with_id(vm['ID'], @client)
                rc = vm_full.info
                raise rc.message if OpenNebula.is_error?(rc)

                value = conf[:value].call(vm_full)

                next unless metric

                metric.set(value, :labels => labels)
            end

            disks = vm.retrieve_elements('TEMPLATE/DISK/DISK_ID')

            @metrics['vm_disks'].set(disks.length, :labels => labels)

            labels_disk = labels.clone

            disks.each do |id|
                labels_disk[:disk_id] = id

                DISK_METRICS.each do |name, conf|
                    next unless conf[:value]

                    metric = @metrics[name]
                    value  = conf[:value].call(id, vm)

                    next unless metric

                    metric.set(value, :labels => labels_disk)
                end
            end

            nics  = vm.retrieve_elements('TEMPLATE/NIC/NIC_ID')
            pnics = vm.retrieve_elements('TEMPLATE/PCI/NIC_ID')

            tnics = 0

            tnics += nics.length if nics
            tnics += pnics.length if pnics

            @metrics['vm_nics'].set(tnics, :labels => labels)
        end
    end

end
